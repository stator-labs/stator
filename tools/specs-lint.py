#!/usr/bin/env python3
"""Lint Stator's specs/: size, index registration, links, deltas, and task budgets.

Checks:
  1. specs/INDEX.md and specs/GLOSSARY.md exist.
  2. Every .md file in specs/ has <= MAX_SPEC_LINES lines.
  3. Every canonical .md file in specs/ (outside changes/ and INDEX.md) is linked in specs/INDEX.md.
  4. Relative markdown links in specs/**/*.md resolve to existing files.
  5. Every active specs/changes/<slug>/ holds proposal.md (with deltas) and tasks.md
     (task headings with Context manifest <= MAX_MANIFEST_FILES, Verify, and Done when).

Standard library only. Exit code 1 if any check fails.
Usage: python3 tools/specs-lint.py [--self-test] [repo_root]
"""
import re
import sys
import tempfile
from pathlib import Path

MAX_SPEC_LINES = 200
MAX_MANIFEST_FILES = 12
DELTA_RE = re.compile(r"^\s*(?:#{1,6}\s+|\*\*)\s*(ADDED|MODIFIED|REMOVED|RENAMED)\b", re.M)
LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
TASK_HEADING_RE = re.compile(r"^#{2,3}\s+.+$", re.M)


def strip_fences(text: str) -> str:
    """Return text with fenced code blocks removed."""
    out, in_fence = [], False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)


def check_links(md_file: Path, root: Path, problems: list[str]) -> None:
    """Verify relative markdown links in md_file resolve on disk."""
    in_fence = False
    for lineno, line in enumerate(md_file.read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        cleaned = re.sub(r"`[^`]*`", "", line)
        for m in LINK_RE.finditer(cleaned):
            raw = m.group(1).strip().split()[0].strip("<>")
            if not raw or raw.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target_part = raw.split("#", 1)[0]
            if not target_part:
                continue
            resolved = (md_file.parent / target_part).resolve()
            if not resolved.exists():
                problems.append(f"{md_file.relative_to(root)}:{lineno} broken link '{raw}'.")


def count_manifest_bullets(block: str) -> int:
    """Count bullet lines inside the Context manifest subsection of a task block."""
    lines = block.splitlines()
    in_manifest = False
    count = 0
    for line in lines:
        stripped = line.strip()
        if not in_manifest:
            if re.search(r"context\s+manifest", stripped, re.I):
                in_manifest = True
            continue
        if re.match(r"^(?:#{1,6}\s+|\*\*|---)", stripped):
            break
        if re.match(r"^[-*]\s+\S", stripped):
            count += 1
    return count


def check_change_dir(change_dir: Path, root: Path, problems: list[str]) -> None:
    """Validate an active specs/changes/<slug>/ directory."""
    rel_dir = change_dir.relative_to(root)
    proposal = change_dir / "proposal.md"
    tasks = change_dir / "tasks.md"
    if not proposal.is_file():
        problems.append(f"{rel_dir} is missing proposal.md.")
    else:
        body = strip_fences(proposal.read_text(encoding="utf-8"))
        if not DELTA_RE.search(body):
            problems.append(f"{proposal.relative_to(root)} has no ADDED/MODIFIED/REMOVED/RENAMED delta.")

    if not tasks.is_file():
        problems.append(f"{rel_dir} is missing tasks.md.")
        return

    tasks_body = strip_fences(tasks.read_text(encoding="utf-8"))
    matches = list(TASK_HEADING_RE.finditer(tasks_body))
    if not matches:
        problems.append(f"{tasks.relative_to(root)} has no task headings (## or ###).")
        return

    for idx, match in enumerate(matches):
        start = match.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(tasks_body)
        block = tasks_body[start:end]
        title = match.group(0).strip()
        for req in ("Context manifest", "Verify", "Done when"):
            if not re.search(rf"\b{re.escape(req)}\b", block, re.I):
                problems.append(f"{tasks.relative_to(root)} ({title}) is missing '{req}'.")
        n_files = count_manifest_bullets(block)
        if n_files > MAX_MANIFEST_FILES:
            problems.append(
                f"{tasks.relative_to(root)} ({title}) has {n_files} manifest files (max {MAX_MANIFEST_FILES})."
            )


def check_repo(root: Path) -> list[str]:
    """Run all specs/ checks against root and return a list of problems."""
    problems: list[str] = []
    specs = root / "specs"
    index_path = specs / "INDEX.md"
    glossary_path = specs / "GLOSSARY.md"

    if not index_path.is_file():
        problems.append("specs/INDEX.md is missing.")
    if not glossary_path.is_file():
        problems.append("specs/GLOSSARY.md is missing.")
    if not specs.is_dir():
        return problems

    all_mds = sorted(specs.rglob("*.md"))
    for md in all_mds:
        n_lines = len(md.read_text(encoding="utf-8").splitlines())
        if n_lines > MAX_SPEC_LINES:
            problems.append(f"{md.relative_to(root)} is {n_lines} lines (max {MAX_SPEC_LINES}).")
        check_links(md, root, problems)

    index_text = index_path.read_text(encoding="utf-8") if index_path.is_file() else ""
    for md in all_mds:
        rel = md.relative_to(specs).as_posix()
        if rel == "INDEX.md" or rel.startswith("changes/"):
            continue
        if rel not in index_text:
            problems.append(f"specs/{rel} is not linked from specs/INDEX.md.")

    changes = specs / "changes"
    if changes.is_dir():
        for entry in sorted(changes.iterdir()):
            if entry.is_dir():
                check_change_dir(entry, root, problems)

    return problems


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def self_test() -> int:
    """Verify check_repo passes valid trees and catches every rule violation."""
    def make_valid(tmp: Path) -> None:
        _write(tmp / "specs/INDEX.md", "# Index\n- [GLOSSARY.md](GLOSSARY.md)\n")
        _write(tmp / "specs/GLOSSARY.md", "# Glossary\n")

    # 1. Valid minimal specs/ passes
    with tempfile.TemporaryDirectory() as d:
        r = Path(d)
        make_valid(r)
        assert check_repo(r) == [], f"Case 1 failed: {check_repo(r)}"

    # 2. Missing INDEX.md registration fails
    with tempfile.TemporaryDirectory() as d:
        r = Path(d)
        make_valid(r)
        _write(r / "specs/EXTRA.md", "# Extra\n")
        assert any("INDEX.md" in p for p in check_repo(r)), "Case 2 failed"

    # 3. File > 200 lines fails
    with tempfile.TemporaryDirectory() as d:
        r = Path(d)
        make_valid(r)
        _write(r / "specs/GLOSSARY.md", "\n".join(["line"] * 201))
        assert any("max 200" in p for p in check_repo(r)), "Case 3 failed"

    # 4. Broken relative link fails
    with tempfile.TemporaryDirectory() as d:
        r = Path(d)
        make_valid(r)
        _write(r / "specs/GLOSSARY.md", "See [missing](NOPE.md).\n")
        assert any("broken link" in p for p in check_repo(r)), "Case 4 failed"

    # 5. Active specs/changes/demo/ missing tasks.md fails
    with tempfile.TemporaryDirectory() as d:
        r = Path(d)
        make_valid(r)
        _write(r / "specs/changes/demo/proposal.md", "## ADDED\n- New rule\n")
        assert any("missing tasks.md" in p for p in check_repo(r)), "Case 5 failed"

    # 6. Active specs/changes/demo/ with valid proposal and tasks passes
    with tempfile.TemporaryDirectory() as d:
        r = Path(d)
        make_valid(r)
        _write(r / "specs/changes/demo/proposal.md", "## ADDED\n- New rule\n")
        _write(
            r / "specs/changes/demo/tasks.md",
            "## Task 1: Do thing\n**Context manifest:**\n- specs/GLOSSARY.md\n**Verify:** ok\n**Done when:** pass\n",
        )
        assert check_repo(r) == [], f"Case 6 failed: {check_repo(r)}"

    # 7. Task with > 12 manifest files fails
    with tempfile.TemporaryDirectory() as d:
        r = Path(d)
        make_valid(r)
        _write(r / "specs/changes/demo/proposal.md", "## MODIFIED\n- Update rule\n")
        bullets = "\n".join(f"- file_{i}.py" for i in range(13))
        _write(
            r / "specs/changes/demo/tasks.md",
            f"## Task 1: Too big\n**Context manifest:**\n{bullets}\n**Verify:** ok\n**Done when:** pass\n",
        )
        assert any("manifest files" in p for p in check_repo(r)), "Case 7 failed"

    print("specs-lint: self-test OK (7 cases)")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = check_repo(root)
    if problems:
        print("specs-lint: FAIL")
        for p in problems:
            print(f"  - {p}")
        return 1
    specs = root / "specs"
    n_files = len(list(specs.rglob("*.md"))) if specs.is_dir() else 0
    print(f"specs-lint: OK ({n_files} spec files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
