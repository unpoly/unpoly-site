#!/usr/bin/env python3
"""Lists the release notes to read when upgrading Unpoly from one version to another.

Python 3.8+ standard library only. Works from any working directory: the skill root is the
parent of this script's `scripts/` folder.

    python3 scripts/releases.py --from 2.7.2 --to 3.12.0
    python3 scripts/releases.py --from 2.7.2 --breaking

Prints the path of every release note after --from, up to and including --to (default: the
latest version), oldest first. With --breaking, each path is followed by the lines of the
changes that may require changes to your code (⚠️ or ❌), with their line numbers.

The order comes from references/changes/releases.json, which the site build writes in the
same order as https://unpoly.com/changes. This script compares no versions of its own.
"""

import argparse
import json
import os
import re
import sys

SKILL_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join("references", "changes", "releases.json")
# A marker counts at the start of a list item or paragraph only: ❌ also appears in tables and
# code examples. Code fences are skipped.
MARKED_LINE = re.compile(r"^\s*(?:[-*+]\s+|\d+\.\s+)?(⚠️|❌)")
FENCE = re.compile(r"^\s*(```|~~~)")
LEGEND = (
    "⚠️ may require changes to your code. unpoly-migrate.js polyfills the old usage while you migrate.\n"
    "❌ breaks code without a polyfill. Update your code before you upgrade."
)


class UsageError(Exception):
    pass


def load_releases(root):
    with open(os.path.join(root, MANIFEST), encoding="utf-8") as file:
        return json.load(file)


def clean_version(version):
    """`^2.7.2`, `~2.7.2`, `>=2.7.2` or `v2.7.2`, as they appear in package.json or a tag, mean 2.7.2."""
    return re.sub(r"^[\s^~>=<v]+", "", version or "").strip()


def is_pre_release(version):
    return "-" in version


def index_of(releases, version, option):
    versions = [release["version"] for release in releases]
    if version in versions:
        return versions.index(version)
    major = version.split(".")[0]
    same_major = [v for v in versions if v.split(".")[0] == major]
    hint = ("Known %s.x versions: %s" % (major, ", ".join(same_major))) if same_major else ("Known versions: %s … %s" % (versions[0], versions[-1]))
    raise UsageError("%s: unknown Unpoly version %s. %s" % (option, version, hint))


def select(releases, from_version, to_version=None):
    """The releases after from_version, up to and including to_version (default: the latest)."""
    start = index_of(releases, from_version, "--from") + 1
    if to_version:
        end = index_of(releases, to_version, "--to") + 1
    else:
        end = len(releases)
    if end < start:
        raise UsageError("--to %s is older than --from %s" % (to_version, from_version))
    selected = releases[start:end]
    # Pre-releases only matter when upgrading to one.
    if not (to_version and is_pre_release(to_version)):
        selected = [release for release in selected if not is_pre_release(release["version"])]
    return selected


def marked_lines(root, path):
    lines = []
    in_fence = False
    with open(os.path.join(root, path), encoding="utf-8") as file:
        for number, line in enumerate(file, start=1):
            if FENCE.match(line):
                in_fence = not in_fence
            elif not in_fence and MARKED_LINE.match(line):
                lines.append((number, line.strip()))
    return lines


def render(root, releases, breaking=False):
    lines = []
    if breaking:
        lines.append(LEGEND)
        lines.append("")
    for release in releases:
        lines.append(release["path"])
        if breaking:
            for number, line in marked_lines(root, release["path"]):
                lines.append("  L%d: %s" % (number, line))
    return "\n".join(lines)


def main(argv, root=SKILL_ROOT, out=sys.stdout):
    parser = argparse.ArgumentParser(
        description="List the release notes to read when upgrading Unpoly, oldest first.")
    parser.add_argument("--from", dest="from_version", required=True,
                        help="the version the app uses now (not listed)")
    parser.add_argument("--to", dest="to_version",
                        help="the version to upgrade to (listed; default: the latest)")
    parser.add_argument("--breaking", action="store_true",
                        help="also list each change marked with ⚠️ or ❌, with its line number")
    args = parser.parse_args(argv)
    if out is sys.stdout and hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # ⚠️ on a Windows console

    try:
        releases = load_releases(root)
        selected = select(releases, clean_version(args.from_version), clean_version(args.to_version) or None)
    except UsageError as error:
        print(error, file=sys.stderr)
        return 2
    if not selected:
        print("No releases after %s." % clean_version(args.from_version), file=sys.stderr)
        return 0
    print(render(root, selected, breaking=args.breaking), file=out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
