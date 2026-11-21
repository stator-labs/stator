#!/usr/bin/env python3
"""Fail when a tracked file holds an AWS account number or access key ID.

The repo is public. Nothing in git history holds an account number today (audit of
2026-11-20); this keeps it that way. It looks at the shape around a number, not at
any 12 digits, because a SHA256 hash can contain 12 digits in a row.

Finds:
  - an ARN with an account ID:        arn:aws:iam::<12 digits>:role/...
  - an account ID next to its key:    account_id = "<12 digits>", Account: <12 digits>
  - an access key ID:                 AKIA... or ASIA... followed by 16 characters

Never prints the value it matched, or any part of it. A finding is `file:line: kind`,
so the CI log does not become a second copy of the leak.

Allowed: a repeated digit (111111111111) or 123456789012, the AWS documentation
example. A line may end with a comment `identifier-check: ignore <reason>`.

Standard library only.
Usage: python3 tools/identifier-check.py [repo_root]
       python3 tools/identifier-check.py --self-test
Exit code 1 on a finding, or when no file was scanned.
"""
import re
import subprocess
import sys
from pathlib import Path

ID = r"(?<!\d)(?P<v>\d{12})(?!\d)"
CHECKS = [
    ("ARN with an account ID", re.compile(r"(?i)arn:aws[a-z-]*:[a-z0-9-]+:[a-z0-9-]*:<?" + ID)),
    ("account ID next to its key", re.compile(r"(?i)\baccount[_ -]?(?:id|number)?[\"']?\s*[:=]\s*[\"']?" + ID)),
    ("access key ID", re.compile(r"(?<![A-Za-z0-9])(?P<v>(?:AKIA|ASIA)[0-9A-Z]{16})(?![A-Za-z0-9])")),
]
IGNORE = re.compile(r"(?:#|//|<!--)[ \t]*identifier-check:[ \t]*ignore\b")
DOC_EXAMPLE = "123456789012"  # the account ID AWS uses in its own documentation


def allowed(value: str) -> bool:
    return value == DOC_EXAMPLE or (value.isdigit() and len(set(value)) == 1)


def scan_text(text: str) -> list[tuple[int, str]]:
    """(line number, kind) for each finding. Never returns the value."""
    found = []
    for n, line in enumerate(text.splitlines(), 1):
        if IGNORE.search(line):
            continue
        for kind, rx in CHECKS:
            if any(not allowed(m.group("v")) for m in rx.finditer(line)):
                found.append((n, kind))
    return found


def self_test() -> int:
    # Built at run time so this file holds no match itself.
    real = "9" * 11 + "8"
    cases = [
        (f"role = arn:aws:iam::{real}:role/x", 1),
        (f'account_id = "{real}"', 1),
        (f"Account: {real}", 1),
        ("key = AKIA" + "A" * 16, 1),
        (f"role = arn:aws:iam::{'1' * 12}:role/x", 0),  # placeholder
        (f"arn:aws:iam::{DOC_EXAMPLE}:root", 0),  # AWS documentation example
        (f"sha256 {'a' * 20}{real}{'b' * 20}", 0),  # digits inside a hash
        (f'account_id = "{real}"  # identifier-check: ignore test value', 0),
        ("arn:aws:iam::<account>:role/x", 0),  # placeholder, not digits
    ]
    bad = [i for i, (text, want) in enumerate(cases, 1) if len(scan_text(text)) != want]
    if bad:
        print(f"identifier-check: self-test failed on case(s) {bad}", file=sys.stderr)
        return 1
    print(f"identifier-check: self-test OK ({len(cases)} cases)")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    names = subprocess.run(["git", "ls-files", "-z"], cwd=root, check=True,
                           capture_output=True).stdout.decode().split("\0")
    scanned = skipped = 0
    findings = []
    for name in filter(None, names):
        path = root / name
        if not path.is_file():
            continue  # a deleted file still listed, or a symlink to nowhere
        data = path.read_bytes()
        if b"\0" in data:
            skipped += 1  # binary
            continue
        scanned += 1
        for n, kind in scan_text(data.decode("utf-8", errors="replace")):
            findings.append(f"{name}:{n}: {kind}")
    if scanned == 0:
        print("identifier-check: no file scanned (wrong root?)", file=sys.stderr)
        return 1
    for f in findings:
        print(f"identifier-check: {f}", file=sys.stderr)
    if findings:
        print("identifier-check: values are not printed. Use a placeholder such as 111111111111, "
              "or end the line with `# identifier-check: ignore <reason>`.", file=sys.stderr)
        return 1
    print(f"identifier-check: OK ({scanned} files scanned, {skipped} binary skipped)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
