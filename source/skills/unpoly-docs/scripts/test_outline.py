"""Tests for outline.py. Standard library only: run `python3 -m unittest test_outline` from this directory.

The cases are the fixtures of unpoly/bin/outline, the same tool in Node: outline.py must print
exactly what they expect. They are read from the unpoly checkout next to this repository
(vendor/unpoly-local). See tooling/test/fixtures/outline/README.md there for how a case is encoded.
"""

import os
import re
import subprocess
import sys
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "outline.py")
REPO = os.path.abspath(os.path.join(os.path.dirname(SCRIPT), "..", "..", "..", ".."))
FIXTURES = os.path.join(REPO, "vendor", "unpoly-local", "tooling", "test", "fixtures", "outline")


def cases():
    """(expected output file, arguments) for every case, e.g. depth.depth-2.txt runs `--depth=2 depth.md`."""
    for name in sorted(os.listdir(FIXTURES)):
        if not name.endswith(".txt"):
            continue
        stem = name[:-len(".txt")]
        args = []
        depth = re.search(r"\.depth-(\d+)$", stem)
        if depth:
            args.append("--depth=" + depth.group(1))
            stem = stem[:depth.start()]
        args += [part + ".md" for part in stem.split("+")]
        yield name, args


def run(*args):
    return subprocess.run([sys.executable, SCRIPT] + list(args), cwd=FIXTURES,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


class OutlineFixturesTest(unittest.TestCase):

    def setUp(self):
        self.assertTrue(os.path.isdir(FIXTURES), "No outline fixtures at %s. Check out unpoly next to this repository." % FIXTURES)

    def test_prints_the_expected_output_for_every_fixture(self):
        names = []
        for name, args in cases():
            names.append(name)
            with self.subTest(name):
                result = run(*args)
                self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", "replace"))
                with open(os.path.join(FIXTURES, name), "rb") as file:
                    self.assertEqual(result.stdout.decode("utf-8"), file.read().decode("utf-8"))
        # Guard against a fixture folder that moved or emptied: the contract has cases for both
        # options and for several files at once.
        self.assertTrue(any(".depth-" in name for name in names), names)
        self.assertTrue(any("+" in name for name in names), names)

    def test_refuses_a_directory(self):
        result = run(".")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"is a directory", result.stderr)

    def test_refuses_a_missing_file(self):
        result = run("missing.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"No such file: missing.md", result.stderr)

    def test_refuses_a_depth_below_one(self):
        result = run("--depth=0", "depth.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")


if __name__ == "__main__":
    unittest.main()
