#!/usr/bin/env python3
"""PreToolUse guardrail hook for Stator (.agents/hooks.json).

Agent-agnostic guardrail hook for PreToolUse events.
Reads a PreToolUse JSON event on stdin and writes {decision, reason} on stdout.
Run `python3 .agents/hooks/guardrails.py --self-test` to verify every rule.
"""
import json
import re
import sys
from pathlib import Path

DENY_READ = [
    re.compile(r"(^|/)\.env(\.|$)"),
    re.compile(r"\.(pem|key)$", re.I),
    re.compile(r"(^|/)credentials", re.I),
    re.compile(r"\.auto\.tfvars$"),
]

DENY_CMD = [
    (re.compile(r"\bgh\s+pr\s+(merge|review)\b"), "Agents never merge or review PRs."),
    (re.compile(r"\bgh\s+api\b.*pulls/[^/\s]+/(merge|reviews)"), "Agents never merge or review PRs."),
]

ASK_CMD = [
    (re.compile(r"\bgit\s+push\b.*(--force|-f\b|--force-with-lease|--delete\b)"), "Destructive git push needs confirmation."),
    (re.compile(r"\btofu\b.*\b(apply|destroy|import|state)\b"), "State-changing OpenTofu command needs confirmation."),
    (re.compile(r"(^|[;&|\s])aws\s+"), "AWS CLI runs in Yaaf's terminal or CI, not agent sessions."),
    (re.compile(r"\bmake\s+bootstrap\b"), "Bootstrap runs in Yaaf's terminal only."),
    (re.compile(r"\bgh\s+(secret|variable)\s+(set|delete|remove)\b"), "Changing GitHub secrets or variables needs confirmation."),
    (re.compile(r"\bgh\s+api\b.*(-X|--method)\s+(DELETE|PUT)\b"), "Mutating GitHub API call needs confirmation."),
]


def evaluate(event: dict) -> dict:
    call = event.get("toolCall") or {}
    name = call.get("name", "")
    args = call.get("args") or {}

    if name == "read_file":
        path = str(args.get("Path") or args.get("path") or "")
        for rx in DENY_READ:
            if rx.search(path):
                return {"decision": "deny", "reason": f"Blocked reading sensitive file: {Path(path).name}"}
        return {"decision": "allow"}

    if name == "run_command":
        cmd = str(args.get("CommandLine") or args.get("command") or "")
        for rx, reason in DENY_CMD:
            if rx.search(cmd):
                return {"decision": "deny", "reason": reason}
        for rx, reason in ASK_CMD:
            if rx.search(cmd):
                return {"decision": "ask", "reason": reason}
        return {"decision": "allow"}

    return {"decision": "allow"}


def self_test() -> int:
    cases = [
        ({"toolCall": {"name": "read_file", "args": {"Path": "/repo/.env"}}}, "deny"),
        ({"toolCall": {"name": "read_file", "args": {"Path": "/repo/foundation.auto.tfvars"}}}, "deny"),
        ({"toolCall": {"name": "read_file", "args": {"Path": "/repo/key.pem"}}}, "deny"),
        ({"toolCall": {"name": "read_file", "args": {"Path": "/repo/README.md"}}}, "allow"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "gh pr merge 12"}}}, "deny"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "gh api repos/x/y/pulls/1/reviews -X POST"}}}, "deny"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "git push --force origin main"}}}, "ask"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "tofu apply"}}}, "ask"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "aws sts get-caller-identity"}}}, "ask"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "make bootstrap"}}}, "ask"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "python3 tools/docs-lint.py"}}}, "allow"),
    ]
    failed = [i for i, (ev, want) in enumerate(cases, 1) if evaluate(ev)["decision"] != want]
    if failed:
        print(f"guardrails: self-test failed on case(s) {failed}", file=sys.stderr)
        return 1
    print(f"guardrails: self-test OK ({len(cases)} cases)")
    return 0


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    raw = sys.stdin.read().strip()
    event = json.loads(raw) if raw else {}
    print(json.dumps(evaluate(event)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
