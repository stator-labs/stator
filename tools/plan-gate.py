#!/usr/bin/env python3
"""Classify an OpenTofu plan JSON (`tofu show -json tfplan`) into a deployment lane.

Lanes:
  - deny:   hard policy breach: destroying a never-destroy resource, a lab IAM role without
            the permissions boundary or outside the workload path, or a lab IAM policy that
            allows a forbidden action or uses NotAction. Fails CI immediately (exit 1).
  - manual: needs Yaaf's click in `aws-apply`: any delete or replace, any IAM, security,
            budget or org change, a policy unknown at plan time, a stack whose floor is
            manual, a terminal or unlisted stack, or more than max_auto_changes changes.
  - auto:   everything else. Eligible for `aws-apply-auto`.

Rules and the stack list come from platform/stacks.json, which the pipeline reads from main.
Standard library only.
Usage:
  python3 tools/plan-gate.py <stack_dir> <plan.json> [--json]
  python3 tools/plan-gate.py --self-test
"""
import json
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "platform" / "stacks.json"


def load_config(path: Path = CONFIG) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _statements(raw) -> list:
    doc = json.loads(raw)
    stmts = doc.get("Statement") or []
    return [stmts] if isinstance(stmts, dict) else stmts


def classify(stack: str, plan: dict, config: dict = None) -> dict:
    config = config or load_config()
    gate = config["gate"]
    entry = next((s for s in config["stacks"].values() if s["dir"] == stack), None)
    denies: list = []
    manual_reasons: list = []
    counts = {"create": 0, "update": 0, "delete": 0, "replace": 0}
    is_lab = stack.startswith("labs/")

    if entry is None:
        manual_reasons.append(f"stack '{stack}' is not in main's platform/stacks.json yet")
    elif not entry.get("ci"):
        manual_reasons.append(f"stack '{stack}' is terminal only")
    elif entry.get("floor") == "manual":
        manual_reasons.append(f"stack '{stack}' has floor manual")

    for rc in plan.get("resource_changes") or []:
        if rc.get("mode") == "data":
            continue
        addr = rc.get("address", "")
        rtype = rc.get("type", "")
        change = rc.get("change", {})
        actions = change.get("actions") or ["no-op"]
        if actions in (["no-op"], ["read"]):
            continue

        is_delete = "delete" in actions and "create" not in actions
        is_replace = "delete" in actions and "create" in actions
        writes = "create" in actions or "update" in actions
        if is_replace:
            counts["replace"] += 1
        elif is_delete:
            counts["delete"] += 1
        elif actions == ["create"]:
            counts["create"] += 1
        elif actions == ["update"]:
            counts["update"] += 1

        if (is_delete or is_replace) and (rtype in gate["never_destroy_types"] or addr in gate["never_destroy_addresses"]):
            denies.append(f"{addr} ({rtype}) cannot be destroyed or replaced by the pipeline")

        after = change.get("after") or {}
        unknown = change.get("after_unknown") or {}
        if is_lab and rtype == "aws_iam_role" and writes:
            boundary = str(after.get("permissions_boundary") or "")
            if unknown.get("permissions_boundary"):
                manual_reasons.append(f"{addr} permissions boundary is unknown at plan time")
            elif not boundary.endswith(gate["boundary_suffix"]):
                denies.append(f"{addr} in {stack} must attach the permissions boundary")
            if not str(after.get("path") or "/").startswith(gate["workload_role_path"]):
                denies.append(f"{addr} must sit under {gate['workload_role_path']}")

        if is_lab and rtype in ("aws_iam_policy", "aws_iam_role_policy") and writes:
            raw = after.get("policy")
            if unknown.get("policy") or not isinstance(raw, str):
                manual_reasons.append(f"{addr} policy is unknown at plan time")
            else:
                try:
                    for st in _statements(raw):
                        if st.get("Effect") != "Allow":
                            continue
                        if "NotAction" in st:
                            denies.append(f"{addr} allows NotAction, which grants everything else")
                        acts = st.get("Action") or []
                        acts = [acts] if isinstance(acts, str) else acts
                        bad = [a for a in acts if a in gate["forbidden_actions"]]
                        if bad:
                            denies.append(f"{addr} allows forbidden action(s) {bad}")
                except (ValueError, AttributeError):
                    manual_reasons.append(f"{addr} policy is not valid JSON")

        if is_delete or is_replace:
            manual_reasons.append(f"{addr} has destructive action ({'+'.join(actions)})")
        if rtype in gate["manual_types"] or rtype.startswith(tuple(gate["manual_prefixes"])):
            manual_reasons.append(f"{addr} touches a security or governance resource ({rtype})")

    total = sum(counts.values())
    if total > gate["max_auto_changes"]:
        manual_reasons.append(f"{total} resource changes exceed the auto-apply cap ({gate['max_auto_changes']})")

    if denies:
        lane, env = "deny", "none"
    elif manual_reasons:
        lane, env = "manual", "aws-apply"
    else:
        lane, env = "auto", "aws-apply-auto"
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
    real = load_config()  # the committed file must parse and carry every gate key
    for key in ("max_auto_changes", "boundary_suffix", "workload_role_path", "forbidden_actions",
                "never_destroy_types", "never_destroy_addresses", "manual_prefixes", "manual_types"):
        assert key in real["gate"], f"platform/stacks.json gate is missing {key}"

    cfg = {"gate": real["gate"], "stacks": {
        "lab02": {"dir": "labs/02-x/infra", "account": "labs", "ci": True, "floor": "auto"},
        "lab05": {"dir": "labs/05-x/infra", "account": "labs", "ci": True, "floor": "manual"},
        "foundation": {"dir": "platform/infra/foundation", "account": "management", "ci": False},
    }}
    lab = "labs/02-x/infra"
    boundary = "arn:aws:iam::111111111111:policy/stator/stator-boundary"

    def rc(addr, rtype, actions, after=None, unknown=None):
        return {"resource_changes": [{"address": addr, "type": rtype, "change": {
            "actions": actions, "after": after or {}, "after_unknown": unknown or {}}}]}

    def pol(stmt):
        return {"policy": json.dumps({"Statement": [stmt]})}

    cases = [
        ("lab update", lab, rc("aws_lambda_function.api", "aws_lambda_function", ["update"]), "auto"),
        ("lab delete", lab, rc("aws_lambda_function.api", "aws_lambda_function", ["delete"]), "manual"),
        ("role with boundary in workload path", lab, rc("aws_iam_role.r", "aws_iam_role", ["create"],
         {"permissions_boundary": boundary, "path": "/stator/workload/"}), "manual"),
        ("role without boundary", lab, rc("aws_iam_role.r", "aws_iam_role", ["create"],
         {"permissions_boundary": None, "path": "/stator/workload/"}), "deny"),
        ("role with legacy runway boundary", lab, rc("aws_iam_role.r", "aws_iam_role", ["create"],
         {"permissions_boundary": "arn:aws:iam::1:policy/runway/runway-boundary", "path": "/stator/workload/"}), "deny"),
        ("role outside workload path", lab, rc("aws_iam_role.r", "aws_iam_role", ["create"],
         {"permissions_boundary": boundary, "path": "/stator/platform/"}), "deny"),
        ("policy iam:*", lab, rc("aws_iam_role_policy.p", "aws_iam_role_policy", ["create"],
         pol({"Effect": "Allow", "Action": ["iam:*"], "Resource": "*"})), "deny"),
        ("policy NotAction", lab, rc("aws_iam_role_policy.p", "aws_iam_role_policy", ["create"],
         pol({"Effect": "Allow", "NotAction": ["s3:*"], "Resource": "*"})), "deny"),
        ("policy unknown at plan", lab, rc("aws_iam_role_policy.p", "aws_iam_role_policy", ["create"],
         {}, {"policy": True}), "manual"),
        ("terminal stack", "platform/infra/foundation", rc("aws_ce_anomaly_monitor.a", "aws_ce_anomaly_monitor", ["update"]), "manual"),
        ("trail destroy", "platform/infra/foundation", rc("aws_s3_bucket.trail", "aws_s3_bucket", ["delete"]), "deny"),
        ("unlisted stack", "labs/09-new/infra", rc("aws_sqs_queue.q", "aws_sqs_queue", ["create"]), "manual"),
        ("floor manual", "labs/05-x/infra", rc("aws_sqs_queue.q", "aws_sqs_queue", ["create"]), "manual"),
        ("too many changes", lab, {"resource_changes": [
            {"address": f"aws_sqs_queue.q{i}", "type": "aws_sqs_queue", "change": {"actions": ["create"], "after": {}}}
            for i in range(real["gate"]["max_auto_changes"] + 1)]}, "manual"),
    ]
    failed = []
    for name, stack, plan, want in cases:
        got = classify(stack, plan, cfg)
        if got["lane"] != want:
            failed.append(f"{name}: want {want}, got {got['lane']} ({got['denies'] + got['manual_reasons']})")
        if got["lane"] == "manual" and got["environment"] != "aws-apply":
            failed.append(f"{name}: manual must use aws-apply")
    if failed:
        print("plan-gate: self-test FAILED\n  " + "\n  ".join(failed), file=sys.stderr)
        return 1
    print(f"plan-gate: self-test OK ({len(cases)} cases)")
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
