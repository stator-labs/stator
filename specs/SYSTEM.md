---
title: Stator operating system
updated: 2026-11-24
---

# Stator operating system

Stator separates strategic command from tactical execution so agents stay fast, cheap, and accurate without context rot.

## Command model (General and squads)

- **General (strategic):** Yaaf sets direction, answers design interviews, approves canonical `specs/` changes, and decides Tier 2 risks ([human-in-the-loop](../docs/human-in-the-loop.md)).
- **Squads (tactical):** Agents write proposals, run Goldfish reviews, execute atomic tasks in fresh contexts, sync specs, run CI checks, and open ready-for-review PRs.
- **Reporting:** Squads report results first in 15 seconds using `.agents/skills/stator-presenting/SKILL.md`.

## Source of truth split

- **Git (`specs/`):** Holds canonical truth (`INDEX.md`, `GLOSSARY.md`, domain and system specs) and in-flight `specs/changes/<slug>/` folders.
- **Linear (`STAT`):** Tracks active work items, priorities, and short handoffs linking back to Git specs. Linear does not store canonical design truth.

## Four-stage workflow loop

1. **Design (`stator-elephant`):** Load `specs/INDEX.md`, `specs/GLOSSARY.md`, and relevant slices. Interview the General one decision at a time. Write `specs/changes/<slug>/proposal.md` (with `ADDED`, `MODIFIED`, `REMOVED`, `RENAMED` deltas) and `tasks.md`. Write zero implementation code.
2. **Gate (`stator-goldfish`):** Spawn a stateless subagent with zero chat history. Run Lens 1 (clarity, gaps, glossary terms, context budget) for any spec, feature, or lab change. Add Lens 2 (Stator invariants, `$0` idle, AWS tags, IAM/trust, rollback) for infra, trust, CI, or cross-lab/org scope. Skip for typos and tiny doc fixes. Loop with Elephant until `Verdict: PASS`.
3. **Execute (`stator-execute`):** After the General approves the vetted proposal, spawn a fresh-context worker per atomic task (or independent wave). Each worker reads only its task's Context Manifest (well inside 200k tokens), runs `Verify`, and makes one atomic commit. Stop only on Tier 2 triggers or when the same failure repeats twice.
4. **Sync (`stator-living-docs`):** Apply deltas from `proposal.md` into canonical `specs/`, update `specs/INDEX.md` and `specs/GLOSSARY.md`, delete `specs/changes/<slug>/` (`git log` is the archive), sync `README.md` and lab READMEs, run linters, and open one PR.

## Governance and budgets

- Canonical `specs/` files stay human-reviewed; auto-merge stays off whenever a PR edits `specs/`.
- `tools/specs-lint.py` enforces `<= 200` lines per spec file, `specs/INDEX.md` links, valid relative links, explicit deltas, and `<= 12` files per Context Manifest.
