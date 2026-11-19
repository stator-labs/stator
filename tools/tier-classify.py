#!/usr/bin/env python3
"""Classify a PR as Tier 1 (auto-merge allowed) or Tier 2 (a human merges).

Default deny: only the AUTO paths below can be Tier 1. Anything else, a TRUST path,
or a diff over MAX_LINES changed lines is Tier 2. Rules: AGENTS.md, kb/auto-merge-gates.md.

Usage:
  python3 tools/tier-classify.py BASE HEAD   # git diff BASE...HEAD; prints JSON, writes $GITHUB_OUTPUT
  python3 tools/tier-classify.py --self-test
Standard library only.
"""
import fnmatch
import json
import os
import subprocess
import sys

MAX_LINES = 300  # AGENTS.md: more than ~300 changed lines is Tier 2 (scope)

# Files that make the rules, the pipeline, identity or infrastructure. Always Tier 2.
TRUST = [
    ".claude/*", ".github/*", "AGENTS.md", "CLAUDE.md",
    "tools/*", "kb/human-in-the-loop.md", "kb/auto-merge-gates.md",
    ".tflint.hcl", "platform/infra/*", "labs/*/infra/*", "*.tf", "*.tfvars", "*.sh",
]
# The only paths that can be Tier 1.
AUTO = ["*.md", "kb/*", "templates/*", ".obsidian/*"]


def match(path, patterns):
    return any(fnmatch.fnmatch(path, p) for p in patterns)


def classify(changes):
    """changes: list of (path, lines_changed). Returns a dict."""
    trust = sorted(p for p, _ in changes if match(p, TRUST))
    other = sorted(p for p, _ in changes if not match(p, TRUST) and not match(p, AUTO))
    lines = sum(n for _, n in changes)
    reasons = []
    if not changes:
        reasons.append("no changed files")
    if trust:
        reasons.append(f"{len(trust)} trust path(s)")
    if other:
        reasons.append(f"{len(other)} path(s) outside the auto-merge allowlist")
    if lines > MAX_LINES:
        reasons.append(f"{lines} changed lines (max {MAX_LINES})")
    return {"tier": 2 if reasons else 1, "lines": lines, "files": len(changes),
            "trust": trust, "other": other, "reasons": reasons}


def diff_changes(base, head):
    out = subprocess.run(["git", "diff", "--numstat", "--no-renames", f"{base}...{head}"],
                         check=True, capture_output=True, text=True).stdout
    changes = []
    for line in out.splitlines():
        added, deleted, path = line.split("\t", 2)
        # Binary files show "-": count them as over the limit so a human looks.
        n = MAX_LINES + 1 if added == "-" else int(added) + int(deleted)
        changes.append((path, n))
    return changes


def self_test():
    cases = [
        ([("README.md", 4)], 1),
        ([("kb/radar.md", 10), ("labs/00-ground-rules/README.md", 20)], 1),
        ([("AGENTS.md", 1)], 2),                       # trust, although it is markdown
        ([(".claude/settings.json", 1)], 2),
        ([(".github/workflows/tofu.yml", 3)], 2),
        ([("labs/00-ground-rules/infra/budgets.tf", 5)], 2),
        ([("labs/00-ground-rules/infra/README.md", 5)], 2),   # trust wins over *.md
        ([("tools/kb-check.py", 2)], 2),
        ([("apps/api/main.py", 2)], 2),                # unknown path: default deny
        ([("kb/radar.md", 301)], 2),                   # too large
        ([("kb/radar.md", 150), ("README.md", 150)], 1),
        ([], 2),
    ]
    bad = [(c, w, classify(c)["tier"]) for c, w in cases if classify(c)["tier"] != w]
    for c, w, got in bad:
        print(f"FAIL {c}: want tier {w}, got {got}")
    print("tier-classify self-test:", "FAIL" if bad else f"OK ({len(cases)} cases)")
    return 1 if bad else 0


def main(argv):
    if argv[1:] == ["--self-test"]:
        return self_test()
    if len(argv) != 3:
        print(__doc__)
        return 2
    result = classify(diff_changes(argv[1], argv[2]))
    print(json.dumps(result, indent=2))
    if out := os.environ.get("GITHUB_OUTPUT"):
        with open(out, "a", encoding="utf-8") as f:
            f.write(f"tier={result['tier']}\n")
            f.write(f"reasons={'; '.join(result['reasons']) or 'docs only, small'}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
