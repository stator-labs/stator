#!/usr/bin/env python3
"""List OpenTofu stacks for .github/workflows/infrastructure.yml.

A stack is platform/infra/<name>/ or labs/<lab>/infra/ with at least one .tf file.
Its state key is <name>/terraform.tfstate (for a lab: <lab folder>/terraform.tfstate),
except stacks in KEPT_KEYS, renamed after their first apply, which keep their first key.

  tofu-stacks.py check            every stack declares backend "s3" with its own key
  tofu-stacks.py all              all stack dirs, JSON list (bootstrap included)
  tofu-stacks.py changed BASE HEAD
                                  stacks touched between two commits, JSON list.
                                  Excludes bootstrap: only Yaaf applies it.
Standard library only.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BOOTSTRAP = "platform/infra/bootstrap"
# Changes here can affect every stack, so they plan/apply all of them.
SHARED = ("platform/infra/modules/", ".github/workflows/infrastructure.yml", "tools/tofu-stacks.py",
          "tools/checkov/", ".tflint.hcl")
# Stacks renamed after their first apply keep their state key, so the rename moves no state.
KEPT_KEYS = {"00-account-foundation": "00-ground-rules"}


def stacks() -> dict[str, str]:
    """dir -> stack name"""
    found = {}
    for d in sorted((ROOT / "platform/infra").glob("*/")):
        if d.name != "modules" and any(d.glob("*.tf")):
            found[d.relative_to(ROOT).as_posix()] = d.name
    for d in sorted((ROOT / "labs").glob("*/infra/")):
        if any(d.glob("*.tf")):
            found[d.relative_to(ROOT).as_posix()] = d.parent.name
    return found


def check() -> int:
    bad = []
    names: dict[str, str] = {}
    for d, name in stacks().items():
        if name in names:
            bad.append(f"{d}: stack name '{name}' is also used by {names[name]}")
        names[name] = d
        text = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / d).glob("*.tf"))
        if not re.search(r'backend\s+"s3"', text):
            bad.append(f'{d}: no backend "s3" block')
        elif not re.search(rf'key\s*=\s*"{re.escape(KEPT_KEYS.get(name, name))}/terraform\.tfstate"', text):
            bad.append(f'{d}: backend key must be "{KEPT_KEYS.get(name, name)}/terraform.tfstate"')
    for b in bad:
        print(f"tofu-stacks: {b}", file=sys.stderr)
    if not bad:
        print(f"tofu-stacks: OK ({len(names)} stacks)", file=sys.stderr)
    return 1 if bad else 0


def changed(base: str, head: str) -> list[str]:
    all_stacks = [d for d in stacks() if d != BOOTSTRAP]
    if set(base) <= {"0"}:  # first push of a branch: no base to diff against
        return all_stacks
    files = subprocess.run(["git", "diff", "--name-only", f"{base}...{head}"], cwd=ROOT,
                           check=True, capture_output=True, text=True).stdout.split()
    if any(f.startswith(SHARED) for f in files):
        return all_stacks
    return [d for d in all_stacks if any(f.startswith(d + "/") for f in files)]


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "check":
        return check()
    if cmd == "all":
        print(json.dumps(list(stacks())))
        return 0
    if cmd == "changed" and len(sys.argv) == 4:
        print(json.dumps(changed(sys.argv[2], sys.argv[3])))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
