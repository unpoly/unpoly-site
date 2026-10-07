"""Ranking checks for search.py against a real, built skill.

Run from the scripts/ directory:

    UNPOLY_SKILL_DIR=/path/to/skills/unpoly-docs python3 -m unittest test_ranking

All tests skip when UNPOLY_SKILL_DIR is unset or has no references/ directory.
Adjust expectations in the CASES table below; each row becomes its own test.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import search  # noqa: E402

# (queries, expected path, must rank within top N)
# Exact symbols must rank first; plain-English queries within the top 3.
CASES = [
    # Exact identifiers, in the spellings an agent might use
    (["up.render"], "references/api/up-render-function.md", 1),
    (["up.render()"], "references/api/up-render-function.md", 1),
    (["up-follow"], "references/api/up-follow-selector.md", 1),
    (["[up-follow]"], "references/api/up-follow-selector.md", 1),
    (["up.follow"], "references/api/up-follow-function.md", 1),
    (["up:link:follow"], "references/api/up-link-follow-event.md", 1),
    (["up.layer.open"], "references/api/up-layer-open-function.md", 1),
    (["up:layer:open"], "references/api/up-layer-open-event.md", 1),
    (["up.$compiler"], "references/api/up-dollar-compiler-function.md", 1),
    (["X-Up-Target"], "references/api/x-up-target-header.md", 1),
    (["up.Layer"], "references/api/up-layer-class.md", 1),
    (["up.link"], "references/api/up-link-module.md", 1),
    (["up.fragment"], "references/api/up-fragment-module.md", 1),
    (["up.Layer.prototype.accept"], "references/api/up-layer-prototype-accept-function.md", 1),
    (["[up-keep]"], "references/api/up-keep-selector.md", 1),
    (["up:fragment:loaded"], "references/api/up-fragment-loaded-event.md", 1),
    (["up.validate"], "references/api/up-validate-function.md", 1),
    # [up-target] has no page: it is a parameter of [up-follow] (and others), and a guide
    (["up-target"], "references/api/up-follow-selector.md", 3),
    (["up-target", "targeting fragments"], "references/learn/targeting-fragments.md", 3),
    # Parameters, which have no page of their own: the feature that documents them
    (["up-accept-location"], "references/api/up-layer-new-selector.md", 1),
    (["[up-dismiss-location]"], "references/api/up-layer-new-selector.md", 1),
    (["up.render options.target"], "references/api/up-render-function.md", 1),
    (["up.layer.open options.onAccepted"], "references/api/up-layer-open-function.md", 1),

    # Plain English
    (["validate form"], "references/learn/validation.md", 3),
    (["close overlay"], "references/learn/closing-overlays.md", 3),
    (["open overlay"], "references/learn/opening-overlays.md", 3),
    (["preserve element across updates"], "references/learn/preserving-elements.md", 3),
    (["cache requests"], "references/learn/caching.md", 3),
    (["polling"], "references/learn/polling.md", 3),
    (["upgrade unpoly migrate"], "references/changes/upgrading.md", 3),
    (["loading indicator", "progress bar"], "references/learn/progress-bar.md", 3),
    (["lazy loading content"], "references/learn/lazy-loading.md", 3),
    (["infinite scrolling"], "references/learn/infinite-scrolling.md", 3),
    (["flash messages"], "references/learn/flashes.md", 3),
    (["targeting fragments"], "references/learn/targeting-fragments.md", 3),
]

SKILL_DIR = os.environ.get("UNPOLY_SKILL_DIR", "")
HAVE_SKILL = bool(SKILL_DIR) and os.path.isdir(os.path.join(SKILL_DIR, "references"))
SKIP_REASON = ("set UNPOLY_SKILL_DIR to a built unpoly-docs skill (a folder with references/) "
               "to run the ranking checks")


@unittest.skipUnless(HAVE_SKILL, SKIP_REASON)
class RankingTest(unittest.TestCase):
    index = None

    @classmethod
    def setUpClass(cls):
        cls.index = search.Index(search.load_documents(SKILL_DIR))

    def check(self, queries, expected, top):
        paths = [document["path"] for _score, document in self.index.search(queries)]
        rank = paths.index(expected) + 1 if expected in paths else None
        self.assertTrue(
            rank is not None and rank <= top,
            "{0!r}: expected {1} in top {2}, got rank {3}. Top 5:\n  {4}".format(
                queries, expected, top, rank, "\n  ".join(paths[:5])))


def _add_case(number, queries, expected, top):
    def test(self):
        self.check(queries, expected, top)
    slug = "".join(c if c.isalnum() else "_" for c in " ".join(queries).lower()).strip("_")
    test.__name__ = "test_{0:02d}_{1}".format(number, slug)
    setattr(RankingTest, test.__name__, test)


for _number, (_queries, _expected, _top) in enumerate(CASES, 1):
    _add_case(_number, _queries, _expected, _top)


if __name__ == "__main__":
    unittest.main()
