#!/usr/bin/env python3
"""Lint Stator's docs: size, links, lab status and writing style.

Checks (rules in docs/index.md):
  1. docs/ holds at most MAX_DOC_FILES files.
  2. No markdown file in docs/ or labs/ exceeds MAX_LINES lines.
  3. Every file in docs/ (except index.md) is linked from docs/index.md.
  4. docs/radar.md has at most MAX_RADAR_ROWS table rows.
  5. No session/meeting/status notes in the repo.
  6. Each lab's README status matches the emoji in the root README lab table.
  7. Prose has no stock phrases and no em dashes.

Standard library only. Exit code 1 if any check fails.
Usage: python3 tools/docs-lint.py [repo_root]
"""
import re
import sys
from pathlib import Path

MAX_DOC_FILES = 8
MAX_LINES = 250
MAX_RADAR_ROWS = 25
STATUS_EMOJI = {"done": "✅", "now": "🔨", "next": "💡", "idea": "💡"}

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
docs = root / "docs"
problems: list[str] = []
SKIP_DIRS = {".git", ".terraform"}  # VCS internals and downloaded OpenTofu providers/modules


def ours(p: Path) -> bool:
    return not SKIP_DIRS.intersection(p.relative_to(root).parts)


doc_files = sorted(p for p in docs.rglob("*") if p.is_file() and ours(p))
if len(doc_files) > MAX_DOC_FILES:
    problems.append(f"docs/ has {len(doc_files)} files (max {MAX_DOC_FILES}). Merge, move into a lab README, or delete.")

for p in [p for p in list(docs.rglob("*.md")) + list((root / "labs").rglob("*.md")) if ours(p)]:
    n = len(p.read_text(encoding="utf-8").splitlines())
    if n > MAX_LINES:
        problems.append(f"{p.relative_to(root)} is {n} lines (max {MAX_LINES}). Cut it or split it by lab.")

index = (docs / "index.md").read_text(encoding="utf-8") if (docs / "index.md").exists() else ""
for p in doc_files:
    rel = p.relative_to(docs).as_posix()
    if rel == "index.md":
        continue
    if rel not in index and p.name not in index:
        problems.append(f"docs/{rel} is not linked from docs/index.md. Link it or delete it.")

radar = docs / "radar.md"
if radar.exists():
    rows = [l for l in radar.read_text(encoding="utf-8").splitlines() if l.startswith("|")]
    data_rows = max(0, len(rows) - 2)  # minus header and separator
    if data_rows > MAX_RADAR_ROWS:
        problems.append(f"docs/radar.md has {data_rows} rows (max {MAX_RADAR_ROWS}). Move adopted items into labs and delete dropped ones.")

for p in root.rglob("*.md"):
    if not ours(p):
        continue
    if re.search(r"(^|/)(sessions?|meetings?|standups?|status)(/|$)", p.relative_to(root).as_posix()):
        problems.append(f"{p.relative_to(root)} looks like a session/status note. Put handoffs in the Linear issue and the PR instead.")

readme = (root / "README.md").read_text(encoding="utf-8")
for lab_readme in sorted((root / "labs").glob("*/README.md")):
    text = lab_readme.read_text(encoding="utf-8")
    m = re.search(r"^status:\s*(\w+)", text, re.M)
    if not m:
        problems.append(f"{lab_readme.relative_to(root)} has no status in its frontmatter.")
        continue
    folder = lab_readme.parent.name
    row = next((l for l in readme.splitlines() if f"labs/{folder}/" in l), None)
    want = STATUS_EMOJI.get(m.group(1))
    if row is None:
        problems.append(f"labs/{folder} is missing from the root README lab table.")
    elif want and want not in row:
        problems.append(f"labs/{folder}: status '{m.group(1)}' but the root README shows something else (expected {want}).")

# 7. Writing style (.agents/skills/stator-writing). Stock phrases and em dashes fail.
STOCK = re.compile(r"\b(seamless(ly)?|robust|leverag\w*|cutting-edge|game-chang\w*|delve|pivotal|testament to"
                   r"|in order to|due to the fact|it is important to note|best-in-class|world-class)\b", re.I)
prose = [root / "README.md", root / "AGENTS.md", *root.glob("templates/*.md"), *root.glob("labs/*/README.md"),
         *(root / ".agents").rglob("*.md"), *(root / "platform").rglob("README.md"), *(root / "tools").glob("*.md"),
         *(p for p in docs.rglob("*.md") if "research" not in p.relative_to(docs).parts)]
for p in sorted(p for p in set(prose) if p.exists() and ours(p)):
    fenced = False
    for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("```"):
            fenced = not fenced
        if fenced:
            continue
        where = f"{p.relative_to(root)}:{n}"
        if m := STOCK.search(line):
            problems.append(f"{where} uses the stock phrase '{m.group(0)}'. Say the concrete thing.")
        if "—" in re.sub(r"\|\s*—\s*(?=\|)", "|", line):  # a lone — in a table cell means "no value"
            problems.append(f"{where} has an em dash. Use a period, colon, comma or parentheses.")

if problems:
    print("docs-lint: FAIL")
    for p in problems:
        print(f"  - {p}")
    sys.exit(1)
print(f"docs-lint: OK ({len(doc_files)} docs files, radar within limit, lab table in sync)")
