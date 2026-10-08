"""Tests for search.py. Standard library only: run `python3 -m unittest` from this directory."""

import contextlib
import io
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import search  # noqa: E402


def page(heading, body="", **meta):
    """A reference file in the generator's format. Keyword args become front matter."""
    lines = ["---"]
    for key, value in meta.items():
        lines.append('{0}: "{1}"'.format(key, value))
    lines += [
        "---",
        '<nav aria-label="Unpoly docs">[All docs](../../SKILL.md) · [navcrumb](x.md)</nav>',
        "",
        "# " + heading,
        "",
        body,
        "",
        '<nav aria-label="Guides">',
        "",
        "- [Learn: Navfooter guide](../learn/navfooter.md)",
        "",
        "</nav>",
    ]
    return "\n".join(lines) + "\n"


class CorpusTestCase(unittest.TestCase):
    """Builds a skill root in a temp dir. Subclasses fill `self.files` before calling write()."""

    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)

    def write(self, files):
        for path, content in files.items():
            full = os.path.join(self.root, path)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w", encoding="utf-8") as handle:
                handle.write(content)

    def results(self, *queries):
        index = search.Index(search.load_documents(self.root))
        return index.search(list(queries))

    def paths(self, *queries):
        return [document["path"] for _score, document in self.results(*queries)]

    def run_cli(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = search.main(["--root", self.root] + list(args))
        return status, output.getvalue()


class TokenizeTest(unittest.TestCase):
    def test_strips_punctuation_from_token_ends(self):
        self.assertEqual(search.tokenize("up.render( [up-target] end. (see:"),
                         ["up.render", "up-target", "end", "see"])

    def test_keeps_inner_dots_dashes_colons_and_dollars(self):
        self.assertEqual(search.tokenize("up:link:follow up.$compiler X-Up-Target"),
                         ["up:link:follow", "up.$compiler", "x-up-target"])

    def test_splits_call_syntax_at_parens_and_commas(self):
        self.assertEqual(search.tokenize("up.render([target], [options])"),
                         ["up.render", "target", "options"])

    def test_lowercases(self):
        self.assertEqual(search.tokenize("up.Layer.prototype.accept"), ["up.layer.prototype.accept"])

    def test_keeps_unicode_letters(self):
        self.assertEqual(search.tokenize("Größe café"), ["größe", "café"])

    def test_empty(self):
        self.assertEqual(search.tokenize(""), [])
        self.assertEqual(search.tokenize("... -- ::"), [])

    def test_compound_tokens_expand_to_weak_parts(self):
        terms = dict(search.expand("up.layer"))
        self.assertEqual(terms["up.layer"], 1.0)
        self.assertEqual(terms["up"], search.PART_WEIGHT)
        self.assertEqual(terms["layer"], search.PART_WEIGHT)

    def test_plain_words_expand_to_a_weak_stem(self):
        self.assertEqual(dict(search.expand("caching")), {"caching": 1.0, "cach": search.STEM_WEIGHT})

    def test_stem(self):
        self.assertEqual({search.stem(w) for w in ("cache", "cached", "caching", "caches")}, {"cach"})
        self.assertEqual(search.stem("form"), "form")       # too short to strip
        self.assertEqual(search.stem("up-follow"), "up-follow")  # only plain words

    def test_normalize_name(self):
        self.assertEqual(search.normalize_name("[up-follow]"), "up-follow")
        self.assertEqual(search.normalize_name("up.render()"), "up.render")


class FrontMatterTest(unittest.TestCase):
    def test_json_quoted_values(self):
        meta, body = search.parse_front_matter('---\nname: "[up-follow]"\nurl: "a \\"b\\""\n---\nbody\n')
        self.assertEqual(meta, {"name": "[up-follow]", "url": 'a "b"'})
        self.assertEqual(body, "body\n")

    def test_value_with_colon(self):
        meta, _ = search.parse_front_matter('---\nname: "up:link:follow"\nurl: "https://unpoly.com/x"\n---\n')
        self.assertEqual(meta["name"], "up:link:follow")
        self.assertEqual(meta["url"], "https://unpoly.com/x")

    def test_absent_keys(self):
        meta, _ = search.parse_front_matter('---\narea: "Learn"\n---\n')
        self.assertNotIn("name", meta)
        self.assertNotIn("visibility", meta)

    def test_no_front_matter(self):
        self.assertEqual(search.parse_front_matter("# Title\n"), ({}, "# Title\n"))

    def test_unclosed_front_matter_is_body(self):
        self.assertEqual(search.parse_front_matter('---\nname: "x"\n'), ({}, '---\nname: "x"\n'))


class BodyTest(unittest.TestCase):
    def test_title_strips_chip(self):
        self.assertEqual(search.clean_title("up.render([target], [options]) (JavaScript function)"),
                         "up.render([target], [options])")
        self.assertEqual(search.clean_title("Linking to fragments (module up.link)"),
                         "Linking to fragments")

    def test_title_keeps_call_parens(self):
        self.assertEqual(search.clean_title("up.render([target], [options])"),
                         "up.render([target], [options])")

    def test_title_and_headings_strip_kramdown_ids(self):
        self.assertEqual(search.clean_title("Closing overlays {#closing}"), "Closing overlays")
        self.assertEqual(search.clean_heading("options.target {#options.target}"), "options.target")

    def test_split_body(self):
        title, headings, lines = search.split_body(
            "# Main (Guide)\n\nIntro\n\n## Section {#sec}\n\ntext\n")
        self.assertEqual(title, "Main")
        self.assertEqual(headings, ["Section"])
        self.assertIn("## Section", lines)
        self.assertNotIn("# Main (Guide)", lines)

    def test_skips_one_line_and_multi_line_navs(self):
        _title, _headings, lines = search.split_body(
            '<nav aria-label="Unpoly docs">[All](x.md)</nav>\n# T\nkept\n<nav aria-label="Guides">\n\n- link\n\n</nav>\nafter\n')
        self.assertEqual([line for line in lines if line], ["kept", "after"])

    def test_keeps_code_blocks_and_ignores_headings_and_navs_inside_them(self):
        title, headings, lines = search.split_body(
            "```sh\n# install it\n<nav>\n```\n# Real title\n")
        self.assertEqual(title, "Real title")
        self.assertEqual(headings, [])
        self.assertIn("# install it", lines)
        self.assertIn("<nav>", lines)


class RankingTest(CorpusTestCase):
    def test_exact_name_ranks_symbol_page_first(self):
        self.write({
            "references/api/up-follow-selector.md": page(
                "[up-follow] (HTML selector)", "Follows this link.", name="[up-follow]", area="API"),
            "references/learn/following-links.md": page(
                "Following links", "Use [up-follow]. " * 30 + "up-follow up-follow", area="Learn"),
        })
        for query in ("[up-follow]", "up-follow"):
            self.assertEqual(self.paths(query)[0], "references/api/up-follow-selector.md", query)

    def test_identifier_heading_a_section_ranks_its_page_first(self):
        self.write({
            "references/api/up-layer-new-selector.md": page(
                "[up-layer=new] (HTML selector)",
                "Opens an overlay.\n\n" + "Other text. " * 80 + "\n\n#### [up-accept-location] {#up-accept-location}\n\nCloses it.",
                name="[up-layer=new]", area="API"),
            "references/learn/closing-overlays.md": page(
                "Closing overlays", "Set [up-accept-location] to close an overlay. " * 3, area="Learn"),
        })
        self.assertEqual(self.paths("up-accept-location")[0], "references/api/up-layer-new-selector.md")

    def test_exact_name_matches_call_syntax(self):
        self.write({
            "references/api/up-render-function.md": page(
                "up.render([target]) (JavaScript function)", "Renders.", name="up.render", area="API"),
            "references/learn/rendering.md": page("Rendering", "Call up.render() " * 20, area="Learn"),
        })
        self.assertEqual(self.paths("up.render()")[0], "references/api/up-render-function.md")

    def test_plain_words_find_compound_identifiers(self):
        self.write({"references/api/up-follow-selector.md": page(
            "[up-follow] (HTML selector)", "Updates a fragment.", name="[up-follow]")})
        self.assertEqual(self.paths("follow"), ["references/api/up-follow-selector.md"])

    def test_up_does_not_explode_scores_or_prefix_match(self):
        # `up` is a part of nearly every identifier, so its IDF must stay near zero.
        self.write({
            "references/api/a.md": page("up.render", "up.render up-follow up:link:follow"),
            "references/api/b.md": page("up.layer", "up.layer up.layer.open"),
            "references/api/c.md": page("up-target", "up-target widget"),
            "references/learn/d.md": page("Linking", "[up-follow] up.link"),
            "references/changes/upgrading.md": page("Upgrading", "upgrade notes"),
        })
        self.assertNotIn("references/changes/upgrading.md", self.paths("up"))  # no prefix match
        up_score = max(score for score, _document in self.results("up"))
        self.assertLess(up_score, self.results("up.layer")[0][0] / 5)

    def test_stems_match_inflections(self):
        self.write({"references/learn/validation.md": page("Validating forms", "Text.")})
        self.assertEqual(self.paths("validate form"), ["references/learn/validation.md"])

    def test_title_outranks_body(self):
        self.write({
            "references/learn/a.md": page("Polling", "Text."),
            "references/learn/b.md": page("Other", "We mention polling once."),
        })
        self.assertEqual(self.paths("polling"), ["references/learn/a.md", "references/learn/b.md"])

    def test_deprecated_pages_are_down_weighted(self):
        self.write({
            "references/api/a.md": page("widget", "widget", visibility="deprecated"),
            "references/api/b.md": page("widget", "widget"),
            "references/api/c.md": page("widget", "widget", visibility="experimental"),
        })
        self.assertEqual(self.paths("widget")[-1], "references/api/a.md")

    def test_changelog_pages_are_down_weighted_by_kind(self):
        self.write({
            "references/changes/3-11-0.md": page("Unpoly 3.11.0", "widget", area="Changes", released="2025-01-01"),
            "references/changes/upgrading.md": page("widget", "widget", area="Changes"),
            "references/learn/widget.md": page("widget", "widget", area="Learn"),
        })
        self.assertEqual(self.paths("widget"), [
            "references/learn/widget.md",
            "references/changes/upgrading.md",
            "references/changes/3-11-0.md",
        ])

    def test_hubs_are_indexed_but_down_weighted(self):
        self.write({
            "references/learn/index.md": page("Learn", "widget"),
            "references/learn/widget.md": page("Other", "widget"),
        })
        self.assertEqual(self.paths("widget"), ["references/learn/widget.md", "references/learn/index.md"])

    def test_or_semantics_across_terms_and_queries(self):
        self.write({
            "references/learn/a.md": page("One", "alpha"),
            "references/learn/b.md": page("Two", "beta"),
            "references/learn/both.md": page("Three", "alpha beta"),
        })
        self.assertEqual(set(self.paths("alpha beta")), {
            "references/learn/a.md", "references/learn/b.md", "references/learn/both.md"})
        self.assertEqual(self.paths("alpha", "beta")[0], "references/learn/both.md")

    def test_nav_links_and_kramdown_ids_are_not_indexed(self):
        self.write({"references/learn/a.md": page("Title", "## Heading {#secretid}\n\ntext")})
        self.assertEqual(self.paths("navcrumb"), [])
        self.assertEqual(self.paths("navfooter"), [])
        self.assertEqual(self.paths("secretid"), [])
        self.assertEqual(self.paths("heading"), ["references/learn/a.md"])

    def test_no_matches(self):
        self.write({"references/learn/a.md": page("Title", "text")})
        self.assertEqual(self.paths("nonexistentterm"), [])

    def test_finds_nested_files(self):
        self.write({"references/learn/start/links.md": page("Link to fragments", "text")})
        self.assertEqual(self.paths("fragments"), ["references/learn/start/links.md"])


class PhraseTest(CorpusTestCase):
    def setUp(self):
        super().setUp()
        self.write({
            "references/learn/a.md": page("One", "Close **the** overlay. Overlay close the."),
            "references/learn/b.md": page("Two", "The overlay close. Overlay close the."),
        })

    def test_page_containing_the_phrase_ranks_higher(self):
        self.assertEqual(self.paths("close the overlay"), ["references/learn/a.md", "references/learn/b.md"])

    def test_phrase_ignores_case_whitespace_and_markdown(self):
        self.assertEqual(self.paths("CLOSE   the\noverlay")[0], "references/learn/a.md")

    def test_phrase_is_a_bonus_not_a_filter(self):
        self.assertEqual(set(self.paths("close the overlay")), {"references/learn/a.md", "references/learn/b.md"})
        self.assertEqual(set(self.paths("overlay vanish")), {"references/learn/a.md", "references/learn/b.md"})

    def test_separate_arguments_are_no_phrase(self):
        scores = dict((d["path"], score) for score, d in self.results("close", "the", "overlay"))
        self.assertAlmostEqual(scores["references/learn/a.md"], scores["references/learn/b.md"])

    def test_query_phrases(self):
        self.assertEqual(search.query_phrases(["Close  the overlay", "up.render"]), [" close the overlay "])


class ExclusionTest(CorpusTestCase):
    def setUp(self):
        super().setUp()
        self.write({
            "references/learn/drawer.md": page("Drawers", "An overlay that slides in."),
            "references/learn/modal.md": page("Modals", "An overlay in the center, a modal."),
            "references/api/up-modal.md": page("[up-modal] (HTML selector)", "Opens an overlay."),
        })

    def test_split_queries(self):
        self.assertEqual(search.split_queries(["overlay -modal", "-up-modal", "x-up-target"]),
                         (["overlay  ", " ", "x-up-target"], ["modal", "up-modal"]))

    def test_exclusion_inside_a_quoted_argument(self):
        self.assertEqual(self.paths("overlay -modal"), ["references/learn/drawer.md"])

    def test_exclusion_as_separate_argument(self):
        self.assertEqual(self.paths("overlay", "-modal"), ["references/learn/drawer.md"])

    def test_inner_dashes_are_no_exclusion(self):
        self.assertIn("references/api/up-modal.md", self.paths("up-modal"))

    def test_cli_treats_single_dash_arguments_as_exclusions(self):
        status, output = self.run_cli("overlay", "-modal", "--limit", "5")
        self.assertEqual(status, 0)
        self.assertIn("references/learn/drawer.md", output)
        self.assertNotIn("modal.md", output)

    def test_cli_exclusion_inside_a_quoted_argument(self):
        _status, output = self.run_cli("overlay -modal")
        self.assertEqual(output.count("<result "), 1)

    def test_cli_needs_a_word_besides_exclusions(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            self.run_cli("-modal")
        self.assertEqual(raised.exception.code, 2)

    def test_split_exclusion_args_keeps_option_values(self):
        self.assertEqual(search.split_exclusion_args(["--limit", "-1", "-h", "-modal", "x"]),
                         (["--limit", "-1", "-h", "x"], ["-modal"]))


class OutputTest(CorpusTestCase):
    def setUp(self):
        super().setUp()
        self.write({
            "references/api/up-render-function.md": page(
                "up.render([target], [options]) (JavaScript function)",
                "Replaces elements on the page.\n\n" + "Filler text.\n\n" * 30 +
                "## Targets\n\nUse a [target selector](../learn/targeting.md) like `.zebra` here.\n",
                name="up.render", area="API"),
            "references/learn/other.md": page("Other zebra", "zebra"),
        })

    def test_result_block_format(self):
        status, output = self.run_cli("up.render", "--limit", "1")
        self.assertEqual(status, 0)
        lines = output.strip().split("\n")
        self.assertRegex(lines[0], r'^<result score="\d+\.\d" path="references/api/up-render-function.md">$')
        self.assertEqual(lines[1], "<title>up.render([target], [options])</title>")
        self.assertTrue(lines[2].startswith("<snippet>") and lines[2].endswith("</snippet>"))
        self.assertEqual(lines[3], "</result>")

    def test_symbol_page_snippet_is_the_lead(self):
        _status, output = self.run_cli("up.render", "--limit", "1")
        self.assertIn("<snippet>Replaces elements on the page.", output)

    def test_snippet_shows_match_context_with_compact_links(self):
        _status, output = self.run_cli("zebra")
        block = next(block for block in output.split("</result>") if "up-render-function" in block)
        self.assertIn("Use a target selector like `.zebra` here.", block)
        self.assertNotIn("Replaces elements", block)

    def test_limit(self):
        _status, output = self.run_cli("zebra", "--limit", "1")
        self.assertEqual(output.count("<result "), 1)
        _status, output = self.run_cli("zebra")
        self.assertEqual(output.count("<result "), 2)

    def test_no_matches_message(self):
        status, output = self.run_cli("nonexistentterm")
        self.assertEqual(status, 0)
        self.assertIn("No matches", output)

    def test_escapes_only_own_tags(self):
        self.assertEqual(search.escape_own_tags('<div up-target=".a"></snippet></result>'),
                         '<div up-target=".a">&lt;/snippet>&lt;/result>')

    def test_missing_references_dir(self):
        with contextlib.redirect_stderr(io.StringIO()):
            status = search.main(["--root", os.path.join(self.root, "nope"), "x"])
        self.assertEqual(status, 1)

    def test_help(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as raised:
            search.main(["--help"])
        self.assertEqual(raised.exception.code, 0)
        self.assertIn("--limit", output.getvalue())
        self.assertIn("-modal", output.getvalue())


class WorkingDirectoryTest(CorpusTestCase):
    def test_default_root_is_parent_of_scripts_dir(self):
        here = os.path.dirname(os.path.abspath(search.__file__))
        self.assertEqual(search.default_root(), os.path.dirname(here))

    def test_paths_are_root_relative_regardless_of_cwd(self):
        self.write({"references/learn/a.md": page("Widget", "text")})
        original = os.getcwd()
        try:
            os.chdir(tempfile.gettempdir())
            self.assertEqual(self.paths("widget"), ["references/learn/a.md"])
        finally:
            os.chdir(original)


if __name__ == "__main__":
    unittest.main()
