---
name: stator-execute
description: Fresh-context squad execution (GSD-core style). Runs atomic tasks from an approved, Goldfish-vetted change proposal in clean 200k-bounded contexts with atomic commits.
---

# Stator Execute (fresh-context squads)

Use this skill after the General approves a change proposal that has `Verdict: PASS` from `stator-goldfish`.

## Rules

1. **Check the gate first.** Confirm `specs/changes/<slug>/proposal.md` has Goldfish `PASS` and General approval.
2. **One fresh worker per task.** Never run an entire multi-task proposal inside one bloated context window.
3. **Respect the Context Manifest.** Give each worker ONLY its task block from `tasks.md`, the files in its Context Manifest, and `specs/GLOSSARY.md`. This keeps every turn sharp and well inside 200k tokens.
4. **Escalate by exception.** Pause and send a 15-second `stator-presenting` ask to the General ONLY if:
   - A task hits an unlisted Tier 2 risk (AWS apply, cost > `$0`, IAM/trust, deletion, scope change).
   - The same verification failure happens twice.

## Execution loop

1. Read `specs/changes/<slug>/tasks.md` and group independent tasks into waves.
2. For each task in the current wave, launch a fresh-context worker with instructions to:
   - Read only the files in its **Context manifest** (plus `specs/GLOSSARY.md`).
   - Implement the **Action**.
   - Run every **Verify** command and confirm all **Done when** checks pass.
   - Commit the task's changes atomically (`<area>: <imperative change>`) with a Linear magic-word trailer in the body (`Part of STAT-<N> (<title>)` or `Refs STAT-<N> (<title>)`) so Linear links each commit without closing the issue early.
   - Return a short proof summary (files changed, verify command output, commit hash).
3. Track completed tasks without pulling full file contents into coordinator context.
4. Once all tasks pass, invoke `stator-living-docs` to merge deltas, clean up `specs/changes/<slug>/`, run all linters, and open one PR.
