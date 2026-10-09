import io
import json
import os
import tempfile
import unittest

import releases

RELEASES = [
    {"version": "2.7.1", "released": "2023-01-01", "path": "references/changes/2-7-1.md"},
    {"version": "2.7.2", "released": "2023-02-01", "path": "references/changes/2-7-2.md"},
    {"version": "3.0.0-rc1", "released": "2023-03-01", "path": "references/changes/3-0-0-rc1.md"},
    {"version": "3.0.0", "released": "2023-04-01", "path": "references/changes/3-0-0.md"},
    {"version": "3.10.0", "released": "2025-01-23", "path": "references/changes/3-10-0.md"},
]

NOTES = {
    "references/changes/3-0-0.md": "# Version 3.0.0\n\n- New feature\n- ⚠️ Renamed up.foo to up.bar\n",
    "references/changes/3-10-0.md": (
        "# Version 3.10.0\n\n- ⚠️ Removed [up-baz]\n- Fixed a bug\n- ❌ Dropped IE 11\n\n"
        "| Old | New |\n| --- | --- |\n| ❌ foo | bar |\n\n```js\n- ⚠️ not a change\n```\n"
    ),
}


class ReleasesTest(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.root, "references", "changes"))
        with open(os.path.join(self.root, releases.MANIFEST), "w", encoding="utf-8") as file:
            json.dump(RELEASES, file)
        for release in RELEASES:
            with open(os.path.join(self.root, release["path"]), "w", encoding="utf-8") as file:
                file.write(NOTES.get(release["path"], "# Version %s\n" % release["version"]))

    def run_script(self, *argv):
        out = io.StringIO()
        status = releases.main(list(argv), root=self.root, out=out)
        return status, out.getvalue().splitlines()

    def test_lists_releases_after_from_up_to_the_latest(self):
        status, lines = self.run_script("--from", "2.7.1")
        self.assertEqual(status, 0)
        self.assertEqual(lines, ["references/changes/2-7-2.md", "references/changes/3-0-0.md",
                                 "references/changes/3-10-0.md"])

    def test_to_is_inclusive(self):
        _, lines = self.run_script("--from", "2.7.1", "--to", "3.0.0")
        self.assertEqual(lines, ["references/changes/2-7-2.md", "references/changes/3-0-0.md"])

    def test_skips_pre_releases_unless_upgrading_to_one(self):
        _, lines = self.run_script("--from", "2.7.2", "--to", "3.0.0-rc1")
        self.assertEqual(lines, ["references/changes/3-0-0-rc1.md"])

    def test_uses_the_manifest_order_not_string_order(self):
        _, lines = self.run_script("--from", "3.0.0")
        self.assertEqual(lines, ["references/changes/3-10-0.md"])

    def test_cleans_up_version_ranges_and_tags(self):
        _, caret = self.run_script("--from", "^2.7.2")
        _, tag = self.run_script("--from", "v2.7.2")
        self.assertEqual(caret, tag)
        self.assertEqual(caret[0], "references/changes/3-0-0.md")

    def test_breaking_lists_marked_lines_with_numbers_and_the_legend(self):
        _, lines = self.run_script("--from", "2.7.2", "--breaking")
        self.assertEqual("\n".join(lines[:2]), releases.LEGEND)
        self.assertIn("references/changes/3-0-0.md", lines)
        self.assertIn("  L4: - ⚠️ Renamed up.foo to up.bar", lines)
        self.assertIn("  L3: - ⚠️ Removed [up-baz]", lines)
        self.assertIn("  L5: - ❌ Dropped IE 11", lines)

    def test_breaking_ignores_markers_in_tables_and_code(self):
        _, lines = self.run_script("--from", "3.0.0", "--breaking")
        marked = [line for line in lines if line.startswith("  L")]
        self.assertEqual(marked, ["  L3: - ⚠️ Removed [up-baz]", "  L5: - ❌ Dropped IE 11"])

    def test_unknown_version_is_a_usage_error_naming_the_major_versions(self):
        status, _ = self.run_script("--from", "2.7.9")
        self.assertEqual(status, 2)
        with self.assertRaises(releases.UsageError) as context:
            releases.select(RELEASES, "2.7.9")
        self.assertIn("2.7.1, 2.7.2", str(context.exception))

    def test_to_older_than_from_is_a_usage_error(self):
        status, _ = self.run_script("--from", "3.0.0", "--to", "2.7.2")
        self.assertEqual(status, 2)

    def test_nothing_after_the_latest(self):
        status, lines = self.run_script("--from", "3.10.0")
        self.assertEqual(status, 0)
        self.assertEqual(lines, [])


if __name__ == "__main__":
    unittest.main()
