#!/usr/bin/env python3
"""Turn `aws resourcegroupstaggingapi get-resources` output into a Markdown report.

Dry run only: this script reads JSON on stdin and prints Markdown. It deletes nothing.
The tagging API returns ARNs and tags but no creation time, so this report cannot say how
old a resource is. Age comes from each service's own lookup, added together with that
service's delete permission.

Account numbers in ARNs are replaced with "(account)".

Usage: aws resourcegroupstaggingapi get-resources \\
         --tag-filters Key=runway:ephemeral,Values=true | python3 tools/reaper.py
Standard library only.
"""
import json
import sys


def tag(tags: list[dict], key: str) -> str:
    return next((t["Value"] for t in tags if t["Key"] == key), "")


def hide_account(arn: str) -> str:
    """The repo is public and so is the job summary: never print the AWS account number."""
    parts = arn.split(":")
    if len(parts) > 4 and parts[4]:
        parts[4] = "(account)"
    return ":".join(parts)


def service(arn: str) -> str:
    return arn.split(":")[2] if arn.count(":") >= 2 else "unknown"


def main() -> int:
    data = json.load(sys.stdin)
    found = data.get("ResourceTagMappingList", [])
    rows = sorted((service(r["ResourceARN"]), hide_account(r["ResourceARN"]),
                   tag(r.get("Tags", []), "lab"), tag(r.get("Tags", []), "project")) for r in found)
    print("## Reaper dry run\n")
    print("Nothing is deleted. Tags carry no creation time, so no resource is checked against the 6-hour limit yet.\n")
    if not rows:
        print("No resources are tagged `runway:ephemeral=true`.")
        return 0
    print(f"{len(rows)} resource(s) tagged `runway:ephemeral=true`:\n")
    print("| Service | Resource | Lab | Project |\n|---|---|---|---|")
    for svc, arn, lab, project in rows:
        print(f"| {svc} | `{arn}` | {lab or 'none'} | {project or 'none'} |")
    stray = [r for r in rows if r[3] != "runway"]
    if stray:
        print(f"\n{len(stray)} of them lack `project=runway`. The reaper must never delete those.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
