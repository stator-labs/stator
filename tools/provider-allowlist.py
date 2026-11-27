#!/usr/bin/env python3
"""Refuse a stack whose providers could run code during `tofu plan`.

`tofu plan` runs provider code, so a PR that adds the `external` provider, an `http`
data source or a custom provider runs its own code with the plan role's credentials
(Snyk "GitFlops", 2024). The reusable plan workflow runs this from main's checkout,
before `tofu init`, against the PR's files.

Checks per stack:
  - `.terraform.lock.hcl` exists and every provider in it is in ALLOWED.
    `tofu init -lockfile=readonly` then refuses any provider missing from the lockfile.
  - no `.terraform/` or `terraform.d/` folder is committed: both can hold provider
    binaries that init would pick up from the working directory.

Usage:
  python3 tools/provider-allowlist.py <stack_dir> [<stack_dir> ...]
  python3 tools/provider-allowlist.py --self-test
Standard library only.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

# Providers whose plan-time behaviour is API reads only. Add one only after reading what its
# data sources do: anything that runs a program or makes arbitrary HTTP calls stays out.
ALLOWED = {
    "registry.opentofu.org/hashicorp/aws",
    "registry.opentofu.org/hashicorp/random",
    "registry.opentofu.org/hashicorp/tls",
}

LOCK_PROVIDER = re.compile(r'^provider\s+"([^"]+)"', re.MULTILINE)


def committed(path: Path) -> bool:
    """True if git tracks anything under path. Outside a git work tree, fall back to existence."""
    try:
        out = subprocess.run(["git", "ls-files", "--", path.name], cwd=path.parent,
                             capture_output=True, text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return path.exists()
    return bool(out.strip())


def check(stack: Path) -> list[str]:
    problems = []
    for name in (".terraform", "terraform.d"):
        if committed(stack / name):
            problems.append(f"{stack}: committed {name}/ can carry provider binaries; remove it")
    lock = stack / ".terraform.lock.hcl"
    if not lock.is_file():
        return problems + [f"{stack}: no .terraform.lock.hcl; run `tofu providers lock` and commit it"]
    found = LOCK_PROVIDER.findall(lock.read_text(encoding="utf-8"))
    if not found:
        problems.append(f"{stack}: .terraform.lock.hcl lists no providers")
    for addr in found:
        if addr not in ALLOWED:
            problems.append(f"{stack}: provider {addr} is not allowed in CI plans (see tools/provider-allowlist.py)")
    return problems


def self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        ok = root / "ok"
        ok.mkdir()
        (ok / ".terraform.lock.hcl").write_text('provider "registry.opentofu.org/hashicorp/aws" {\n}\n')
        assert check(ok) == [], check(ok)

        ext = root / "ext"
        ext.mkdir()
        (ext / ".terraform.lock.hcl").write_text(
            'provider "registry.opentofu.org/hashicorp/aws" {\n}\n'
            'provider "registry.opentofu.org/hashicorp/external" {\n}\n')
        assert any("hashicorp/external" in p for p in check(ext)), check(ext)

        nolock = root / "nolock"
        nolock.mkdir()
        assert any("no .terraform.lock.hcl" in p for p in check(nolock))

        mirror = root / "mirror"
        (mirror / "terraform.d").mkdir(parents=True)
        (mirror / ".terraform.lock.hcl").write_text('provider "registry.opentofu.org/hashicorp/aws" {\n}\n')
        assert any("terraform.d/" in p for p in check(mirror))
    print("provider-allowlist: self-test OK")
    return 0


def main() -> int:
    args = sys.argv[1:]
    if args == ["--self-test"]:
        return self_test()
    if not args:
        print(__doc__, file=sys.stderr)
        return 2
    problems = [p for d in args for p in check(Path(d))]
    for p in problems:
        print(f"::error::provider-allowlist: {p}")
    if not problems:
        print(f"provider-allowlist: OK ({len(args)} stacks)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
