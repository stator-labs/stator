#!/usr/bin/env python3
"""List OpenTofu stacks for the Infrastructure workflow, from platform/stacks.json.

A stack is platform/infra/<name>/ or labs/<lab>/infra/ with at least one .tf file. Every
stack must be listed in platform/stacks.json. Its state key is <state_key or id>/terraform.tfstate.
Stacks with "ci": false are terminal only: CI lints and tests them but never plans or applies them.

  tofu-stacks.py check            every stack is listed and declares backend "s3" with its key
  tofu-stacks.py all              all stack dirs, JSON list (terminal stacks included)
  tofu-stacks.py ci               stack dirs CI plans and applies, JSON list
  tofu-stacks.py changed BASE HEAD
                                  CI stacks touched between two commits, JSON list
Standard library only.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "platform" / "stacks.json"


def load() -> dict:
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def on_disk() -> list:
    found = []
    for d in sorted((ROOT / "platform/infra").glob("*/")):
        if d.name != "modules" and any(d.glob("*.tf")):
            found.append(d.relative_to(ROOT).as_posix())
    for d in sorted((ROOT / "labs").glob("*/infra/")):
        if any(d.glob("*.tf")):
            found.append(d.relative_to(ROOT).as_posix())
    return found


def stacks() -> dict:
    """dir -> config entry (with its id)"""
    return {s["dir"]: {**s, "id": sid} for sid, s in load()["stacks"].items()}


def ci_stacks() -> list:
    return [d for d, s in stacks().items() if s.get("ci")]


def check() -> int:
    bad = []
    listed = stacks()
    for d in on_disk():
        if d not in listed:
            bad.append(f"{d}: not listed in platform/stacks.json")
    for d, s in listed.items():
        if not (ROOT / d).is_dir():
            bad.append(f"{d}: listed as '{s['id']}' but missing on disk")
            continue
        key = s.get("state_key", s["id"])
        text = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / d).glob("*.tf"))
        if not re.search(r'backend\s+"s3"', text):
            bad.append(f'{d}: no backend "s3" block')
        elif not re.search(rf'key\s*=\s*"{re.escape(key)}/terraform\.tfstate"', text):
            bad.append(f'{d}: backend key must be "{key}/terraform.tfstate"')
        if s.get("account") not in ("management", "labs"):
            bad.append(f"{d}: account must be management or labs")
        if s.get("ci") and s.get("account") == "management":
            bad.append(f"{d}: management stacks are terminal only (SCPs do not bind that account)")
        if s.get("floor", "auto") not in ("auto", "manual"):
            bad.append(f"{d}: floor must be auto or manual")
    for b in bad:
        print(f"tofu-stacks: {b}", file=sys.stderr)
    if not bad:
        print(f"tofu-stacks: OK ({len(listed)} stacks)", file=sys.stderr)
    return 1 if bad else 0


def changed(base: str, head: str) -> list:
    ci = ci_stacks()
    if set(base) <= {"0"}:  # no base to diff against
        return ci
    files = subprocess.run(["git", "diff", "--name-only", f"{base}...{head}"], cwd=ROOT,
                           check=True, capture_output=True, text=True).stdout.split()
    if any(f.startswith(tuple(load()["shared_paths"])) for f in files):
        return ci
    return [d for d in ci if any(f.startswith(d + "/") for f in files)]


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "check":
        return check()
    if cmd == "all":
        print(json.dumps(list(stacks())))
        return 0
    if cmd == "ci":
        print(json.dumps(ci_stacks()))
        return 0
    if cmd == "changed" and len(sys.argv) == 4:
        print(json.dumps(changed(sys.argv[2], sys.argv[3])))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
