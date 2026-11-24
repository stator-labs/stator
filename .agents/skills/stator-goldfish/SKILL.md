---
name: stator-goldfish
description: Stateless, zero-context cold-eyes review gate (Goldfish role). Audits a change proposal using only canonical specs and referenced files before execution begins.
---

# Stator Goldfish (cold-eyes review gate)

A plan is ready only when a stranger with zero chat history can verify and execute it from the written files alone.

## When to run (tiered gate)

- **Skip:** Typos and tiny single-file doc fixes.
- **Lens 1 (Clarity and Gaps):** Required for any spec, feature, or lab change.
- **Lens 2 (Invariants and Risk):** Also required when touching `platform/`, AWS infra, IAM/OIDC/trust, CI workflows, cost, or cross-lab/org boundaries.

## Isolation rule

Spawn a **fresh subagent with zero conversation history**. Pass ONLY:
1. `specs/INDEX.md` and `specs/GLOSSARY.md`.
2. Canonical `specs/*.md` files named in the proposal.
3. `specs/changes/<slug>/proposal.md` and `specs/changes/<slug>/tasks.md`.
4. Exact existing code paths listed in the task Context Manifests.

Do NOT paste chat summaries, earlier drafts, or unstated intent.

## Review lenses

- **Lens 1 (Clarity and Gaps):**
  - Unstated assumptions or terms missing from `specs/GLOSSARY.md`.
  - Vague `Action`, `Verify`, or `Done when` criteria.
  - Missing failure modes, edge cases, or out-of-scope leaks.
  - Task bloat: any task with `> 12` manifest files or risk of exceeding a 200k-token window.
- **Lens 2 (Invariants and Risk):**
  - Violates `$0` idle, mandatory tags (`project`, `lab`, `ephemeral`), or pinned SHAs/digests.
  - Missing rollback path or Tier 2 approval callout.
  - Hidden cross-lab coupling or guardrail bypasses.

## Output format

Return strictly:
- `Verdict: PASS` or `Verdict: FAIL`
- **Blockers:** Numbered list (`file:section` + concrete fix needed), or `None`.
- **Notes:** Optional non-blocking improvements.

If `FAIL`, Elephant fixes blockers and spawns a new stateless Goldfish until `PASS`. Update `Goldfish sign-off` in `proposal.md` when `PASS`.
