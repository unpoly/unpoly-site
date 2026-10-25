#!/usr/bin/env python3
"""Prints the outline of Markdown files: the title, the opening paragraph and every heading with
the lines its section spans, so you can read one section instead of the whole page.

Python 3.8+ standard library only.

    python3 scripts/outline.py references/learn/validation.md
    python3 scripts/outline.py references/api/up-render-function.md --depth=4

--depth=N lists headings down to that level (default 3: `##` and `###`, as `#` is the title).

Keep in sync with unpoly/bin/outline (unpoly/tooling/outline.mjs), the same tool for the
contributing guides. Both must pass unpoly/tooling/test/fixtures/outline/, which is the contract
between them and describes the format: change a rule here, change it there, and pin it with a
fixture. test_outline.py runs every fixture.
"""

import argparse
import os
import re
import sys

# What a line is. SKIP holds nothing we would list or quote: frontmatter, comments, horizontal
# rules and the navigation that a generator wraps around the real text.
SKIP = "skip"
CODE = "code"
BLANK = "blank"
TEXT = "text"
HEADING = "heading"
UNDERLINE = "underline"

# JavaScript's whitespace, for `\s` and trim(). Unlike Python's, it holds a byte order mark.
WHITESPACE = "\t\n\v\f\r \u00a0\u1680" + "".join(map(chr, range(0x2000, 0x200b))) + "\u2028\u2029\u202f\u205f\u3000\ufeff"


def js(source):
    r"""A regular expression of outline.mjs, copied verbatim, with JavaScript's meaning: `\s` is
    JavaScript's whitespace, `.` stops at \r, \u2028 and \u2029, `\d` and `\b` are ASCII."""
    source = source.replace(r"\s", "[" + WHITESPACE + "]").replace(".*", "[^\n\r\u2028\u2029]*")
    return re.compile(source, re.ASCII)


IMAGE = js(r"^\s*(?:\[\s*)?!\[[^\]]*\]\([^)]*\)(?:\]\([^)]*\))?\s*$|^\s*<img\b[^>]*>\s*$")
FENCE_OPEN = js(r"^\s*(`{3,}|~{3,})(.*)$")
FENCE_CLOSE = js(r"^\s*(`+|~+)\s*$")
TOC_OPEN = js(r"^\s*<!--\s*toc\s*-->")
TOC_CLOSE = js(r"<!--\s*(\/toc|tocstop)\s*-->")
COMMENT_OPEN = js(r"^\s*<!--")
COMMENT_CLOSE = js(r"-->")
NAV_OPEN = js(r"^\s*<nav\b")
NAV_CLOSE = js(r"<\/nav>")
ATX = js(r"^(#{1,6})[ \t]+(.*)$")
ATX_CLOSING = js(r"(^|[ \t]+)#+[ \t]*$")
SETEXT_UNDERLINE = js(r"^ {0,3}(=+|-+)\s*$")
NOT_SETEXT_TEXT = js(r"^\s|^([-*+]|\d+[.)])(\s|$)|^>|\|")
RULE = js(r"^ {0,3}([-*_])( *\1){2,}\s*$")
ANCHOR = js(r"\s*\{#[^}]*\}\s*$")


def split_lines(markdown):
    lines = [line[:-1] if line.endswith("\r") else line for line in markdown.split("\n")]
    # A final newline ends the last line rather than starting another, as `wc -l` counts.
    if lines[-1] == "":
        lines.pop()
    return lines


def classify(lines):
    """Gives every line a kind, and marks headings with their level and text. Lines are 0-based here."""
    kinds = []
    headings = []
    start = 0

    if lines and lines[0] == "---" and "---" in lines[1:]:
        start = lines.index("---", 1) + 1
        kinds += [SKIP] * start

    # The fence that opened the current code block, or the end of the current skipped block.
    fence = None
    skip_until = None

    for i in range(start, len(lines)):
        line = lines[i]

        if fence:
            kinds.append(CODE)
            closing = FENCE_CLOSE.match(line)
            if closing and closing.group(1)[0] == fence[0] and len(closing.group(1)) >= len(fence):
                fence = None
            continue

        if skip_until:
            kinds.append(SKIP)
            if skip_until.search(line):
                skip_until = None
            continue

        opening = FENCE_OPEN.match(line)
        # An info string may not hold a backtick, or ```this``` would open a block.
        if opening and not (opening.group(1)[0] == "`" and "`" in opening.group(2)):
            fence = opening.group(1)
            kinds.append(CODE)
            continue

        if TOC_OPEN.match(line):
            skip_until = TOC_CLOSE
            kinds.append(SKIP)
            continue

        if COMMENT_OPEN.match(line):
            if "-->" not in line:
                skip_until = COMMENT_CLOSE
            kinds.append(SKIP)
            continue

        if NAV_OPEN.match(line):
            if "</nav>" not in line:
                skip_until = NAV_CLOSE
            kinds.append(SKIP)
            continue

        if not line.strip(WHITESPACE):
            kinds.append(BLANK)
            continue

        atx = ATX.match(line)
        if atx:
            text = ATX_CLOSING.sub("", atx.group(2), count=1)
            headings.append({"index": i, "level": len(atx.group(1)), "text": heading_text(text)})
            kinds.append(HEADING)
            continue

        underline = SETEXT_UNDERLINE.match(line)
        if underline and i > 0 and is_setext_text(lines[i - 1], kinds[i - 1]):
            kinds[i - 1] = HEADING
            level = 1 if underline.group(1)[0] == "=" else 2
            headings.append({"index": i - 1, "level": level, "text": heading_text(lines[i - 1])})
            kinds.append(UNDERLINE)
            continue

        if RULE.match(line):
            kinds.append(SKIP)
            continue

        kinds.append(TEXT)

    return kinds, headings


def is_setext_text(line, kind):
    """Only a paragraph line can be underlined into a heading. Underneath a list item, a table
    row, a quote or an indented line, a `---` is a horizontal rule."""
    return kind == TEXT and not NOT_SETEXT_TEXT.search(line)


def heading_text(text):
    """`{#anchor}` sets the slug on unpoly.com and is no part of the heading's text."""
    return ANCHOR.sub("", text, count=1).strip(WHITESPACE)


def outline(markdown, depth=3):
    """The title, the opening paragraph and the sections up to `depth`, with 1-based line ranges.
    A section includes its subsections. The intro is the text above the first listed heading."""
    lines = split_lines(markdown)
    kinds, headings = classify(lines)

    # The title is an H1 that comes before any content, so a document that opens with a
    # paragraph has no title, and its first H1 is listed like any other heading.
    first = next((i for i, kind in enumerate(kinds) if kind not in (SKIP, BLANK)), -1)
    title = headings[0] if headings and headings[0]["index"] == first and headings[0]["level"] == 1 else None
    body = [heading for heading in headings if heading is not title]
    listed = [heading for heading in body if heading["level"] <= depth]

    # The opening paragraph: the first run of text lines above the first heading. Code and
    # images may come before it, but are not it.
    summary = []
    start = title["index"] + 1 if title else 0
    stop = body[0]["index"] if body else len(lines)
    for i in range(start, stop):
        if kinds[i] == TEXT and (summary or not IMAGE.search(lines[i])):
            summary.append(lines[i])
        elif summary:
            break

    sections = []
    intro_end = listed[0]["index"] if listed else len(lines)
    if any(kind not in (SKIP, BLANK, UNDERLINE) for kind in kinds[start:intro_end]):
        sections.append((1, intro_end, "(intro)"))

    for heading in listed:
        following = (other for other in body if other["index"] > heading["index"] and other["level"] <= heading["level"])
        end = next(following, {"index": len(lines)})["index"]
        sections.append((heading["index"] + 1, end, "#" * heading["level"] + " " + heading["text"]))

    return {"line_count": len(lines), "title": title and title["text"], "summary": summary, "sections": sections}


def format_outlines(files, depth=3):
    """One block per file, with the range column as wide as its widest entry across all files, so
    several outlines read as one table. `files` is a list of (path, markdown) pairs."""
    outlines = [(path, outline(markdown, depth)) for path, markdown in files]
    ranges = ["%d-%d" % (start, end) for _, result in outlines for start, end, _ in result["sections"]]
    width = max([0] + [len(range_) for range_ in ranges]) + 2

    blocks = []
    for path, result in outlines:
        count = result["line_count"]
        size = "(%d %s)" % (count, "line" if count == 1 else "lines")
        block = ["%s: %s %s" % (path, result["title"], size) if result["title"] else "%s %s" % (path, size)]
        if result["summary"]:
            block += ["  " + line for line in result["summary"]] + [""]
        for start, end, label in result["sections"]:
            block.append("  " + ("%d-%d" % (start, end)).ljust(width) + label)
        blocks.append("\n".join(block))
    return "\n\n".join(blocks)


def positive_int(value):
    if not re.fullmatch("[0-9]+", value) or int(value) < 1:
        raise argparse.ArgumentTypeError("must be a whole number of 1 or more")
    return int(value)


def main(argv, out=sys.stdout):
    parser = argparse.ArgumentParser(
        description="Print the title, opening paragraph and sections of Markdown files, "
                    "with the lines each section spans.")
    parser.add_argument("paths", nargs="+", metavar="file", help="a Markdown file, e.g. a page in references/")
    parser.add_argument("--depth", type=positive_int, default=3,
                        help="list headings down to this level (default 3: ## and ###)")
    args = parser.parse_args(argv)
    if out is sys.stdout and hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # non-ASCII titles on a Windows console

    files = []
    for path in args.paths:
        if os.path.isdir(path):
            print("%s is a directory. Pass the Markdown files in it, e.g. %s/*.md" % (path, path), file=sys.stderr)
            return 2
        if not os.path.exists(path):
            print("No such file: %s" % path, file=sys.stderr)
            return 2
        # newline="" keeps \r\n, so lines are split and counted as outline.mjs does.
        with open(path, encoding="utf-8", errors="replace", newline="") as file:
            files.append((path, file.read()))

    print(format_outlines(files, depth=args.depth), file=out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
