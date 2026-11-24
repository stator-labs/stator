---
name: stator-elephant
description: Context-rich design and spec authoring (Elephant role). Interviews the General, checks specs/GLOSSARY.md, and drafts a change proposal and atomic tasks without writing implementation code.
---

# Stator Elephant (design and spec authoring)

Use this skill when starting non-trivial work (new lab, architecture shift, domain expansion, or cross-module change).

## Hard rules

1. **Write zero implementation code** during this phase. Produce only the change proposal under `specs/changes/<slug>/`.
2. **Load context selectively.** Read `specs/INDEX.md`, `specs/GLOSSARY.md`, and only the canonical specs relevant to the goal.
3. **Explore before asking.** If the codebase answers a question, inspect the files first instead of asking the General.

## Procedure

1. **Align with the General:** Walk the decision tree one question at a time. Offer a recommended choice for each question. Resolve ambiguities in scope, constraints, boundaries, and glossary terms.
2. **Write `specs/changes/<slug>/proposal.md`:**
   - **Why:** 1 to 3 sentences on the problem and goal.
   - **Scope / Out of scope:** Explicit boundaries.
   - **Deltas:** Group exact changes to canonical `specs/*.md` files under `ADDED`, `MODIFIED`, `REMOVED`, or `RENAMED` headings, naming each target file.
   - **Glossary impact:** New or updated terms for `specs/GLOSSARY.md` (or `None`).
   - **Risk and Tier:** State any Tier 2 triggers (AWS apply, cost > `$0`, IAM/trust, deletion, repo-wide rules).
   - **Goldfish sign-off:** Leave as `PENDING` until `stator-goldfish` passes.
3. **Write `specs/changes/<slug>/tasks.md`:**
   Break work into small vertical-slice atomic tasks (`## Task 1: <imperative title>`). Every task MUST contain:
   - **Context manifest:** Bullet list of exact files to read (`<= 12` files, keeping the worker well inside 200k tokens).
   - **Action:** Exact files to change and behavior to implement.
   - **Verify:** Exact command(s) to run and expected output.
   - **Done when:** Observable proof criteria.
4. **Gate before approval:** Run `python3 tools/specs-lint.py`, then pass the proposal to `stator-goldfish`. Only ask the General to approve execution after Goldfish returns `Verdict: PASS`.
