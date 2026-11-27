#!/usr/bin/env python3
"""PreToolUse guardrail hook for Stator.

Wired for Antigravity (.agents/hooks.json: toolCall events, replies {decision, reason})
and for Claude Code (.claude/settings.json: tool_name/tool_input events, replies with
hookSpecificOutput). Same rules for both. For Claude Code an "allow" prints nothing, so
the normal permission prompts still apply.
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
    # Auto-merge on allow-listed PRs is allowed (Policy: trust paths enforces the list);
    # any other merge, and --admin, is not.
    (re.compile(r"\bgh\s+pr\s+merge\b(?!.*--auto)"), "Agents never merge PRs (only --auto on allow-listed files)."),
    (re.compile(r"\bgh\s+pr\s+merge\b.*--admin"), "Agents never bypass branch rules."),
    (re.compile(r"\bgh\s+pr\s+review\b"), "Agents never review PRs."),
    (re.compile(r"\bgh\s+api\b.*pulls/[^/\s]+/(merge|reviews)"), "Agents never merge or review PRs."),
    # Approving or rejecting a deployment is Yaaf's click (AGENTS.md Tier 3).
    (re.compile(r"pending_deployments"), "Agents never approve or reject deployments."),
    (re.compile(r"\bgh\s+api\b.*deployment_protection_rule"), "Agents never approve or reject deployments."),
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


def evaluate_claude(event: dict) -> dict:
    """Map a Claude Code PreToolUse event onto the same rules."""
    name = event.get("tool_name", "")
    inp = event.get("tool_input") or {}
    if name == "Bash":
        return evaluate({"toolCall": {"name": "run_command", "args": {"command": inp.get("command", "")}}})
    if name == "Read":
        return evaluate({"toolCall": {"name": "read_file", "args": {"path": inp.get("file_path", "")}}})
    return {"decision": "allow"}


def claude_reply(result: dict) -> str:
    if result["decision"] == "allow":
        return ""
    return json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": result["decision"],
        "permissionDecisionReason": result.get("reason", ""),
    }})


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
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "gh pr merge 39 --auto"}}}, "allow"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "gh pr merge 39 --auto --admin"}}}, "deny"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine": "gh pr merge 39 --squash"}}}, "deny"),
        ({"toolCall": {"name": "run_command", "args": {"CommandLine":
          "gh api -X POST repos/o/r/actions/runs/1/pending_deployments -f state=approved"}}}, "deny"),
        ({"tool_name": "Bash", "tool_input": {"command": "gh pr merge 5"}}, "deny"),
        ({"tool_name": "Bash", "tool_input": {"command": "gh api repos/o/r/actions/runs/1/pending_deployments"}}, "deny"),
        ({"tool_name": "Bash", "tool_input": {"command": "aws s3 ls"}}, "ask"),
        ({"tool_name": "Bash", "tool_input": {"command": "git status"}}, "allow"),
        ({"tool_name": "Read", "tool_input": {"file_path": "/repo/.env"}}, "deny"),
        ({"tool_name": "Edit", "tool_input": {"file_path": "/repo/x.tf"}}, "allow"),
    ]
    def run(ev):
        return evaluate_claude(ev) if "tool_name" in ev else evaluate(ev)
    failed = [i for i, (ev, want) in enumerate(cases, 1) if run(ev)["decision"] != want]
    if claude_reply({"decision": "allow"}) != "":
        failed.append("claude-allow-prints-nothing")
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
    if "tool_name" in event:  # Claude Code
        out = claude_reply(evaluate_claude(event))
        if out:
            print(out)
        return 0
    print(json.dumps(evaluate(event)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
