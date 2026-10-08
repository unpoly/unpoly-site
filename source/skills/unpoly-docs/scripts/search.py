#!/usr/bin/env python3
"""Full-text search over the Unpoly docs bundled with this skill.

Python 3.8+ standard library only: no packages, no network, no install, no cache files.
Works from any working directory: the skill root is the parent of this script's `scripts/` folder.

Ranking is BM25F over field-weighted tokens (name and title above headings above body), with:

- An exact-name boost, so `up.render` or `[up-follow]` puts that symbol's own page first.
- A smaller boost for an identifier that heads a section of a page, so a parameter like
  `[up-accept-location]` finds the feature that documents it.
- Weak secondary tokens for the parts of compound identifiers (`up-follow` also indexes `up` and
  `follow`) and for crude word stems (`validation` also indexes `validat`), so plain English finds
  API pages and inflected words find each other. There is no prefix matching: common parts like
  `up` occur on every page and get an IDF near zero instead of matching everything.
- Down-weights for deprecated pages, hub pages (`index.md`) and changelog pages.
- A bonus for pages containing a query argument of several words as a phrase. This only
  re-ranks: the words still match with OR semantics.
- Exclusions: a word with a leading `-` (`-modal`) removes every page containing it.
"""

import argparse
import json
import math
import os
import re
import sys
from collections import Counter

# --- tuning ---------------------------------------------------------------------------------------

K1 = 1.2
B = 0.75

FIELD_WEIGHTS = {
    "name": 5.0,      # the symbol's identifier, e.g. `up.render` (API symbol pages only)
    "title": 4.0,     # first `# ` heading, chip stripped
    "headings": 2.0,  # `##`..`######` headings
    "body": 1.0,      # everything else, code blocks included (agents search for code)
}

PART_WEIGHT = 0.3   # `up` and `follow` from `up-follow`
STEM_WEIGHT = 0.5   # `validat` from `validation`

NAME_BOOST = 3.0           # query token equals the page's `name`
HEADING_NAME_BONUS = 1.5   # query identifier heads a section, e.g. a parameter `[up-accept-location]`
PHRASE_BONUS = 1.5         # page contains a multi-word query argument word for word
DEPRECATED_FACTOR = 0.6
HUB_FACTOR = 0.5           # references/*/index.md: link lists that mention everything
RELEASE_FACTOR = 0.5       # release notes (references/changes/3-11-0.md etc.)
CHANGES_GUIDE_FACTOR = 0.9  # other changelog pages, e.g. upgrading.md

DEFAULT_LIMIT = 10
SNIPPET_CHARS = 280

# --- tokenizer ------------------------------------------------------------------------------------

# A token is a run of word characters plus `.`, `:`, `$` and `-`, so identifiers like `up.render`,
# `up:link:follow`, `up.$compiler` and `X-Up-Target` stay whole. Any other character separates
# tokens, which also splits `up.render([target],` into `up.render` and `target`.
WORD_RE = re.compile(r"[\w.:$-]+")
INNER_CHARS = ".:$-"
PART_SPLIT_RE = re.compile(r"[.:$-]+")

STEM_SUFFIXES = ("ations", "ation", "ings", "ing", "ions", "ion", "ments", "ment",
                 "ers", "er", "ies", "ied", "es", "ed", "ly", "s", "e")


def tokenize(text):
    """Lowercased primary tokens, with `.:$-` stripped from the token ends."""
    tokens = []
    for raw in WORD_RE.findall((text or "").lower()):
        token = raw.strip(INNER_CHARS)
        if token:
            tokens.append(token)
    return tokens


def stem(word):
    """Crude suffix stripping for plain words: `caching`, `cached`, `cache` -> `cach`."""
    if not word.isalpha():
        return word
    for suffix in STEM_SUFFIXES:
        if word.endswith(suffix) and len(word) - len(suffix) >= 4:
            return word[:-len(suffix)]
    return word


_expand_cache = {}


def expand(token, stem_weight=STEM_WEIGHT):
    """The terms a token contributes, as (term, weight) pairs: the token itself, the parts of a
    compound token and the stems of plain words. Memoized, since corpus tokens repeat a lot.

    Queries pass `stem_weight=1.0`: a query word stands for its concept, while a page should
    still score higher for the exact word than for an inflection of it."""
    key = (token, stem_weight)
    terms = _expand_cache.get(key)
    if terms is None:
        terms = [(token, 1.0)]
        parts = [part for part in PART_SPLIT_RE.split(token) if part]
        if len(parts) > 1:
            for part in parts:
                terms.append((part, PART_WEIGHT))
                if stem(part) != part:
                    terms.append((stem(part), PART_WEIGHT * stem_weight))
        elif stem(token) != token:
            terms.append((stem(token), stem_weight))
        _expand_cache[key] = terms
    return terms


def normalize_name(name):
    return " ".join(tokenize(name))


# --- parsing --------------------------------------------------------------------------------------

FRONT_MATTER_LINE_RE = re.compile(r"^([A-Za-z0-9_]+):\s*(.*)$")
KRAMDOWN_ID_RE = re.compile(r"\s*\{#[^}]*\}\s*$")
CHIP_RE = re.compile(r"\s+\([^()]*\)$")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
NAV_OPEN_RE = re.compile(r"^\s*<nav\b[^>]*>")
FENCE_RE = re.compile(r"^\s*(```|~~~)")


def parse_value(raw):
    """Values are JSON strings, which the build checks (SkillPackage#front_matter_problems)."""
    return json.loads(raw)


def parse_front_matter(text):
    """Returns (meta, body). Only the flat `key: value` lines our generator writes."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}, text
    meta = {}
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            return meta, "\n".join(lines[index + 1:])
        match = FRONT_MATTER_LINE_RE.match(lines[index])
        if match:
            meta[match.group(1)] = parse_value(match.group(2))
    return {}, text  # unclosed: treat everything as body


def clean_heading(text):
    """Strips a trailing Kramdown id: `Options {#options}` -> `Options`."""
    return KRAMDOWN_ID_RE.sub("", text).strip()


def clean_title(text):
    """`up.render([target]) (JavaScript function)` -> `up.render([target])`."""
    return CHIP_RE.sub("", clean_heading(text)).strip()


def split_body(body):
    """Returns (title, headings, lines): the first `# ` heading, the other headings, and all
    remaining lines (headings included, for snippets). Skips <nav> blocks outside code fences."""
    title = None
    headings = []
    lines = []
    in_fence = False
    in_nav = False
    for line in body.split("\n"):
        if in_nav:
            in_nav = "</nav>" not in line
            continue
        if FENCE_RE.match(line):
            in_fence = not in_fence
        elif not in_fence:
            if NAV_OPEN_RE.match(line):
                in_nav = "</nav>" not in line
                continue
            heading = HEADING_RE.match(line)
            if heading:
                if title is None and len(heading.group(1)) == 1:
                    title = clean_title(heading.group(2))
                    continue
                headings.append(clean_heading(heading.group(2)))
                line = heading.group(1) + " " + clean_heading(heading.group(2))
        lines.append(line)
    return title, headings, lines


def page_factor(path, meta):
    factor = 1.0
    if meta.get("visibility") == "deprecated":
        factor *= DEPRECATED_FACTOR
    if os.path.basename(path) == "index.md":
        factor *= HUB_FACTOR
    elif meta.get("area") == "Changes":
        # Release notes are named after their version (3-11-0.md).
        is_release = re.match(r"^\d+-\d+", os.path.basename(path))
        factor *= RELEASE_FACTOR if is_release else CHANGES_GUIDE_FACTOR
    return factor


def load_document(root, path):
    with open(path, encoding="utf-8") as handle:
        meta, body = parse_front_matter(handle.read())
    relative = os.path.relpath(path, root).replace(os.sep, "/")
    title, headings, lines = split_body(body)
    name = meta.get("name") or ""
    return {
        "path": relative,
        "title": title or os.path.splitext(os.path.basename(path))[0],
        "name": normalize_name(name) if name else None,
        "heading_names": heading_names(headings),
        "factor": page_factor(relative, meta),
        "lines": lines,
        "fields": {
            "name": name,
            "title": title or "",
            "headings": "\n".join(headings),
            "body": "\n".join(lines),
        },
    }


def heading_names(headings):
    """Identifiers that start a heading: the parameters of a feature (`[options.target]`)."""
    names = set()
    for heading in headings:
        tokens = tokenize(heading)
        if tokens and any(char in tokens[0] for char in INNER_CHARS):
            names.add(tokens[0])
    return names


def load_documents(root):
    documents = []
    references = os.path.join(root, "references")
    for directory, subdirectories, files in os.walk(references):
        subdirectories.sort()
        for file in sorted(files):
            if file.endswith(".md"):
                documents.append(load_document(root, os.path.join(directory, file)))
    return documents


# --- index ----------------------------------------------------------------------------------------

class Index:
    """BM25F: each field's term frequency is normalized by that field's length before the fields
    are weighted and summed, so a title match counts the same on a short page and a long guide."""

    def __init__(self, documents):
        self.documents = documents
        self.postings = {}  # term -> {doc_id: normalized, field-weighted frequency}

        # Pass 1: weighted term counts and token length per document and field.
        counts = []
        lengths = {field: [] for field in FIELD_WEIGHTS}
        for document in documents:
            per_field = {}
            for field, text in document["fields"].items():
                tokens = Counter(tokenize(text))
                tf = {}
                for token, count in tokens.items():
                    # The name's parts already occur in the title, so only the whole name counts.
                    for term, weight in (expand(token) if field != "name" else [(token, 1.0)]):
                        tf[term] = tf.get(term, 0.0) + count * weight
                per_field[field] = tf
                lengths[field].append(sum(tokens.values()))
            counts.append(per_field)

        # Pass 2: normalize by field length and fold the fields into one frequency per term.
        averages = {field: (sum(values) / len(values) if values else 0.0) or 1.0
                    for field, values in lengths.items()}
        for doc_id, per_field in enumerate(counts):
            for field, tf in per_field.items():
                norm = 1 - B + B * lengths[field][doc_id] / averages[field]
                factor = FIELD_WEIGHTS[field] / norm
                for term, frequency in tf.items():
                    postings = self.postings.setdefault(term, {})
                    postings[doc_id] = postings.get(doc_id, 0.0) + frequency * factor

    def idf(self, term):
        count = len(self.postings.get(term, ()))
        return math.log(1 + (len(self.documents) - count + 0.5) / (count + 0.5))

    def search(self, queries):
        """OR semantics over all tokens of all queries. Returns [(score, document)], best first.
        Words with a leading `-` are exclusions, see split_queries()."""
        queries, excluded = split_queries(queries)
        query_terms = parse_query(queries)
        names = set(query_names(queries))
        phrases = query_phrases(queries)
        excluded_ids = set()
        for token in excluded:
            excluded_ids.update(self.postings.get(token, ()))
        scores = {}
        for term, query_weight in query_terms.items():
            postings = self.postings.get(term)
            if not postings:
                continue
            idf = self.idf(term)
            for doc_id, tf in postings.items():
                bm25 = tf * (K1 + 1) / (tf + K1)
                score = query_weight * idf * bm25
                # A bonus for this term alone, unaffected by the page's length (a feature with
                # many parameters is long), so the other words of a query keep their say.
                if term in self.documents[doc_id]["heading_names"]:
                    score += query_weight * idf * HEADING_NAME_BONUS
                scores[doc_id] = scores.get(doc_id, 0.0) + score

        results = []
        for doc_id, score in scores.items():
            if doc_id in excluded_ids:
                continue
            document = self.documents[doc_id]
            score *= document["factor"]
            if phrases:
                text = phrase_text(document)
                for phrase in phrases:
                    if phrase in text:
                        score *= PHRASE_BONUS
            if document["name"] and document["name"] in names:
                score *= NAME_BOOST
            results.append((score, document))
        results.sort(key=lambda pair: (-pair[0], pair[1]["path"]))
        return results


EXCLUSION_RE = re.compile(r"(?:^|(?<=\s))-(?=\w)(\S*)")


def split_queries(queries):
    """Returns (queries, excluded): the queries without their exclusion words, and the tokens of
    those words. An exclusion is a word with a leading `-`, as an argument of its own (`-modal`)
    or inside one (`"overlay -modal"`)."""
    excluded = []
    kept = []
    for query in queries:
        for word in EXCLUSION_RE.findall(query):
            excluded.extend(tokenize(word))
        kept.append(EXCLUSION_RE.sub(" ", query))
    return kept, excluded


def query_phrases(queries):
    """Queries of several words, as space-joined tokens to look for in phrase_text()."""
    phrases = []
    for query in queries:
        tokens = tokenize(query)
        if len(tokens) > 1:
            phrases.append(" " + " ".join(tokens) + " ")
    return phrases


def phrase_text(document):
    """The page's tokens joined by single spaces, so a phrase matches regardless of case,
    whitespace, punctuation and Markdown. Built on first use, since only phrase queries need it."""
    text = document.get("phrase_text")
    if text is None:
        fields = document["fields"]
        text = " " + " ".join(tokenize("\n".join([fields["title"], fields["body"]]))) + " "
        document["phrase_text"] = text
    return text


def parse_query(queries):
    """{term: weight} over all queries. Repeated terms count once, at their highest weight."""
    terms = {}
    for query in queries:
        for token in tokenize(query):
            for term, weight in expand(token, stem_weight=1.0):
                terms[term] = max(terms.get(term, 0.0), weight)
    return terms


def query_names(queries):
    """Candidates for the exact-name boost: each token, and each query as a whole."""
    for query in queries:
        tokens = tokenize(query)
        yield from tokens
        yield " ".join(tokens)


# --- output ---------------------------------------------------------------------------------------

LINK_RE = re.compile(r"\[((?:[^\[\]]|\[[^\]]*\])*)\]\([^)\s]*\)")  # [text](url), text may hold [..]


def snippet(document, query_terms, idf, lead=False):
    """A window around the body line that matches the most (IDF-weighted) query terms.
    With `lead=True`, or when no line matches, the page's first paragraph instead."""
    lines = [LINK_RE.sub(r"\1", line).strip() for line in document["lines"]]
    best_index, best_score = None, 0.0
    for index, line in enumerate(lines if not lead else ()):
        terms = {term for token in tokenize(line) for term, _weight in expand(token)}
        score = sum(weight * idf(term) for term, weight in query_terms.items() if term in terms)
        if score > best_score:
            best_index, best_score = index, score

    if best_index is None:
        best_index = next((index for index, line in enumerate(lines)
                           if line and not line.startswith("#") and not FENCE_RE.match(line)), None)
        if best_index is None:
            return ""

    # Grow the window with following lines until it holds enough text.
    end = best_index + 1
    while sum(len(line) for line in lines[best_index:end]) < SNIPPET_CHARS and end < len(lines):
        end += 1
    text = re.sub(r"\s+", " ", " ".join(lines[best_index:end])).strip()

    prefix = "… " if any(lines[:best_index]) else ""
    suffix = " …" if any(lines[end:]) else ""
    if len(text) > SNIPPET_CHARS:
        # Shift the window right if the first matched term would otherwise be cut off.
        lowered = text.lower()
        positions = [lowered.find(term) for term in query_terms if term in lowered]
        start = 0
        if positions and min(positions) > SNIPPET_CHARS * 2 // 3:
            start = min(positions) - SNIPPET_CHARS // 3
            prefix = "… "
        text = text[start:start + SNIPPET_CHARS].strip()
        suffix = " …"
    return prefix + text + suffix


OWN_TAG_RE = re.compile(r"<(/?)(result|title|snippet)\b", re.IGNORECASE)


def escape_own_tags(text):
    # Only our own element names are escaped, so a code sample cannot close a block early.
    # Other markup stays readable (`<div up-target=".foo">`), since agents read this, not parsers.
    return OWN_TAG_RE.sub(r"&lt;\1\2", text)


def render_result(score, document, snippet_text):
    return "\n".join([
        '<result score="{0:.1f}" path="{1}">'.format(score, document["path"]),
        "<title>{0}</title>".format(escape_own_tags(document["title"])),
        "<snippet>{0}</snippet>".format(escape_own_tags(snippet_text)),
        "</result>",
    ])


# --- CLI ------------------------------------------------------------------------------------------

DESCRIPTION = "Search Unpoly's guides, API reference and changelog in this skill."

EPILOG = """\
Pass several queries at once: a page that matches any of them is found, and pages matching more
terms rank higher. Exact identifiers rank their own page first, in any spelling:
  up.render  up.render()  [up-follow]  up-follow  up:link:follow  up.$compiler  X-Up-Target

A query of several words in one quoted argument is also a phrase: pages containing it word for
word rank higher. A word with a leading - excludes every page containing it, as an argument of
its own or inside a quoted one:
  python3 scripts/search.py overlay -modal
  python3 scripts/search.py "overlay -modal"

examples:
  python3 scripts/search.py up.layer.open
  python3 scripts/search.py "close overlay" "dismiss modal" up-dismiss
  python3 scripts/search.py "loading indicator" spinner progress busy feedback
  python3 scripts/search.py --limit 5 "validate form fields while typing"

Each result has a path relative to the skill root. Read the file for the full page.
Release notes (references/changes/) and deprecated pages are ranked lower."""


def default_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


OPTIONS_WITH_VALUE = ("--limit", "--root")


def split_exclusion_args(argv):
    """Returns (argv, exclusions). argparse would take `-modal` for an unknown option, so every
    argument starting with a single `-` (except `-h` and option values) is set aside as an
    exclusion. The script's own options all start with `--`."""
    kept, exclusions = [], []
    takes_value = False
    for arg in argv:
        if takes_value:
            kept.append(arg)
            takes_value = False
        elif arg in OPTIONS_WITH_VALUE:
            kept.append(arg)
            takes_value = True
        elif EXCLUSION_RE.fullmatch(arg) and arg != "-h":
            exclusions.append(arg)
        else:
            kept.append(arg)
    return kept, exclusions


def main(argv):
    argv, exclusions = split_exclusion_args(argv)
    parser = argparse.ArgumentParser(
        prog="search.py", description=DESCRIPTION, epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("queries", nargs="*", metavar="QUERY",
                        help="words, phrases or identifiers (OR semantics); -word excludes pages")
    parser.add_argument("--limit", type=int, default=DEFAULT_LIMIT, metavar="N",
                        help="maximum number of results (default: %(default)s)")
    parser.add_argument("--root", default=default_root(), metavar="DIR",
                        help="skill root containing references/ (default: this skill)")
    args = parser.parse_args(argv)
    queries = args.queries + exclusions
    if not any(tokenize(query) for query in split_queries(queries)[0]):
        parser.error("pass at least one QUERY to search for, not only exclusions")

    if not os.path.isdir(os.path.join(args.root, "references")):
        print("No references/ directory in {0}".format(args.root), file=sys.stderr)
        return 1

    index = Index(load_documents(args.root))
    results = index.search(queries)[:max(args.limit, 0)]
    if not results:
        print("No matches. Try other words, synonyms or exact identifiers (e.g. up.render, "
              "[up-target], up:link:follow), several of them in one call.")
        return 0

    positive, _excluded = split_queries(queries)
    query_terms = parse_query(positive)
    names = set(query_names(positive))
    blocks = []
    for score, document in results:
        # A symbol's own page is best summarized by its lead paragraph.
        lead = document["name"] in names
        blocks.append(render_result(score, document, snippet(document, query_terms, index.idf, lead)))
    print("\n\n".join(blocks))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
