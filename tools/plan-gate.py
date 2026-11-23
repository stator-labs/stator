#!/usr/bin/env python3
"""Classify an OpenTofu plan JSON (`tofu show -json tfplan`) into a deployment lane.

Lanes:
  - deny:   hard policy breach (protected resource destroy, wildcard IAM in a lab,
            lab role without permissions_boundary). Fails CI immediately (exit 1).
  - manual: requires Yaaf's approval click (`aws-foundation-apply` for foundation,
            `aws-apply` for labs with deletes/replaces, IAM/security/budget changes,
            or > MAX_AUTO_CHANGES resources).
  - auto:   safe labs change (0 deletes/replaces, no IAM/security/budget resources,
            <= MAX_AUTO_CHANGES resources). Eligible for `aws-apply-auto`.

Standard library only.
Usage:
  python3 tools/plan-gate.py <stack_dir> <plan.json> [--json]
  python3 tools/plan-gate.py --self-test
"""
import json
import sys
from pathlib import Path

MAX_AUTO_CHANGES = 5

NEVER_DESTROY_TYPES = {
    "aws_organizations_organization",
    "aws_organizations_account",
    "aws_cloudtrail",
}

NEVER_DESTROY_ADDRESSES = {
    "aws_s3_bucket.state",
    "aws_s3_bucket.trail",
    "aws_organizations_policy.labs",
    "aws_organizations_policy_attachment.labs",
}

MANUAL_PREFIXES = (
    "aws_iam_",
    "aws_organizations_",
    "aws_ssoadmin_",
    "aws_identitystore_",
    "aws_kms_",
    "aws_budgets_",
    "aws_ce_",
    "aws_ram_",
    "aws_accessanalyzer_",
)

MANUAL_TYPES = {
    "aws_s3_bucket_policy",
    "aws_s3_bucket_public_access_block",
    "aws_sns_topic_policy",
}


def classify(stack: str, plan: dict) -> dict:
    denies: list[str] = []
    manual_reasons: list[str] = []
    counts = {"create": 0, "update": 0, "delete": 0, "replace": 0}
    is_lab = stack.startswith("labs/")

    if stack == "platform/infra/foundation":
        manual_reasons.append("foundation stack always uses aws-foundation-apply")
    elif not is_lab:
        manual_reasons.append(f"platform stack '{stack}' requires human approval")

    for rc in plan.get("resource_changes") or []:
        if rc.get("mode") == "data":
            continue
        addr = rc.get("address", "")
        rtype = rc.get("type", "")
        actions = rc.get("change", {}).get("actions") or ["no-op"]
        if actions in (["no-op"], ["read"]):
            continue

        is_delete = "delete" in actions and "create" not in actions
        is_replace = "delete" in actions and "create" in actions
        is_create = actions == ["create"]
        is_update = actions == ["update"]

        if is_replace:
            counts["replace"] += 1
        elif is_delete:
            counts["delete"] += 1
        elif is_create:
            counts["create"] += 1
        elif is_update:
            counts["update"] += 1

        if (is_delete or is_replace) and (rtype in NEVER_DESTROY_TYPES or addr in NEVER_DESTROY_ADDRESSES):
            denies.append(f"{addr} ({rtype}) cannot be destroyed or replaced by pipeline")

        after = rc.get("change", {}).get("after") or {}
        if is_lab and rtype == "aws_iam_role" and ("create" in actions or "update" in actions):
            boundary = str(after.get("permissions_boundary") or "")
            if not boundary.endswith((":policy/runway/runway-boundary", ":policy/stator/stator-boundary")):
                denies.append(f"{addr} in {stack} must attach the permissions boundary")

        if is_lab and rtype in ("aws_iam_policy", "aws_iam_role_policy") and ("create" in actions or "update" in actions):
            raw_pol = after.get("policy")
            if isinstance(raw_pol, str) and raw_pol.strip().startswith("{"):
                try:
                    doc = json.loads(raw_pol)
                    stmts = doc.get("Statement") or []
                    if isinstance(stmts, dict):
                        stmts = [stmts]
                    for s in stmts:
                        if s.get("Effect") == "Allow":
                            acts = s.get("Action") or []
                            if isinstance(acts, str):
                                acts = [acts]
                            if any(a in ("*", "iam:*", "organizations:*") for a in acts):
                                denies.append(f"{addr} grants forbidden wildcard action in {acts}")
                except ValueError:
                    pass

        if is_delete or is_replace:
            manual_reasons.append(f"{addr} has destructive action ({'+'.join(actions)})")

        if rtype in MANUAL_TYPES or rtype.startswith(MANUAL_PREFIXES):
            manual_reasons.append(f"{addr} touches security/governance resource ({rtype})")

    total = sum(counts.values())
    if total > MAX_AUTO_CHANGES:
        manual_reasons.append(f"{total} resource changes exceed auto-apply cap ({MAX_AUTO_CHANGES})")

    if denies:
        lane = "deny"
        env = "none"
    elif manual_reasons:
        lane = "manual"
        env = "aws-foundation-apply" if stack == "platform/infra/foundation" else "aws-apply"
    else:
        lane = "auto"
        env = "aws-apply-auto"

    return {
        "stack": stack,
        "lane": lane,
        "environment": env,
        "counts": counts,
        "total_changes": total,
        "denies": denies,
        "manual_reasons": manual_reasons,
    }


def self_test() -> int:
    # 1. Safe no-op / 1-resource lab update -> auto
    r1 = classify("labs/02-serverless-vs-kubernetes/infra", {
        "resource_changes": [
            {"address": "aws_lambda_function.api", "type": "aws_lambda_function",
             "change": {"actions": ["update"], "after": {}}}
        ]
    })
    assert r1["lane"] == "auto" and r1["environment"] == "aws-apply-auto", r1

    # 2. Lab delete -> manual (aws-apply)
    r2 = classify("labs/02-serverless-vs-kubernetes/infra", {
        "resource_changes": [
            {"address": "aws_lambda_function.api", "type": "aws_lambda_function",
             "change": {"actions": ["delete"], "after": {}}}
        ]
    })
    assert r2["lane"] == "manual" and r2["environment"] == "aws-apply", r2

    # 3. Lab IAM role with boundary -> manual (IAM always reviewed, not denied)
    r3 = classify("labs/00-account-foundation/infra", {
        "resource_changes": [
            {"address": "aws_iam_role.reaper", "type": "aws_iam_role",
             "change": {"actions": ["create"], "after": {
                 "permissions_boundary": "arn:aws:iam::111111111111:policy/stator/stator-boundary"
             }}}
        ]
    })
    assert r3["lane"] == "manual" and r3["environment"] == "aws-apply", r3

    # 4. Lab IAM role missing boundary -> deny
    r4 = classify("labs/05-agent-sandboxing/infra", {
        "resource_changes": [
            {"address": "aws_iam_role.bad", "type": "aws_iam_role",
             "change": {"actions": ["create"], "after": {"permissions_boundary": None}}}
        ]
    })
    assert r4["lane"] == "deny", r4

    # 5. Lab IAM policy with iam:* -> deny
    r5 = classify("labs/05-agent-sandboxing/infra", {
        "resource_changes": [
            {"address": "aws_iam_role_policy.bad", "type": "aws_iam_role_policy",
             "change": {"actions": ["create"], "after": {
                 "policy": json.dumps({"Statement": [{"Effect": "Allow", "Action": ["iam:*"], "Resource": "*"}]})
             }}}
        ]
    })
    assert r5["lane"] == "deny", r5

    # 6. Foundation change -> manual (aws-foundation-apply)
    r6 = classify("platform/infra/foundation", {
        "resource_changes": [
            {"address": "aws_ce_anomaly_monitor.account", "type": "aws_ce_anomaly_monitor",
             "change": {"actions": ["delete", "create"], "after": {}}}
        ]
    })
    assert r6["lane"] == "manual" and r6["environment"] == "aws-foundation-apply", r6

    # 7. Foundation attempting to destroy trail bucket -> deny
    r7 = classify("platform/infra/foundation", {
        "resource_changes": [
            {"address": "aws_s3_bucket.trail", "type": "aws_s3_bucket",
             "change": {"actions": ["delete"], "after": {}}}
        ]
    })
    assert r7["lane"] == "deny", r7

    print("plan-gate: self-test OK (7 cases)")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    stack = sys.argv[1]
    plan = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    res = classify(stack, plan)
    if "--json" in sys.argv[3:]:
        print(json.dumps(res, indent=2))
    else:
        c = res["counts"]
        print(f"plan-gate: {stack} -> lane={res['lane']} (env={res['environment']}, "
              f"+{c['create']} ~{c['update']} -{c['delete']} ±{c['replace']})")
        for d in res["denies"]:
            print(f"  DENY: {d}")
        for m in res["manual_reasons"]:
            print(f"  manual: {m}")
    return 1 if res["lane"] == "deny" else 0


if __name__ == "__main__":
    sys.exit(main())
