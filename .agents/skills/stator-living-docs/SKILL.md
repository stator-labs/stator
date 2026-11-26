---
name: stator-living-docs
description: OpenSpec delta-and-delete sync and living-doc hygiene. Merges approved deltas into canonical specs/, deletes specs/changes/<slug>/, runs linters, and prepares one PR.
---

# Stator Living Docs (delta-and-delete sync)

Run this skill as the final step of an approved change proposal, after all tasks in `tasks.md` pass verification.

## Procedure

1. **Merge deltas into canonical truth:**
   Read `specs/changes/<slug>/proposal.md` and apply every `ADDED`, `MODIFIED`, `REMOVED`, and `RENAMED` block to the target files in `specs/`.
2. **Update index and glossary:**
   - Register any new canonical spec file in `specs/INDEX.md` and remove deleted ones.
   - Add or update any changed domain terms in `specs/GLOSSARY.md`.
   - Update `updated:` dates in touched spec frontmatter.
3. **Delete the change folder:**
   Remove `specs/changes/<slug>/` completely (`git log` is the archive).
4. **Sync surrounding docs:**
   - Update `README.md` or affected `labs/NN-*/README.md` (Proof, Cost receipt, Decisions, What broke) if the change touched a lab or repo structure.
   - Keep `docs/` within its limits (`<= 8` files, `<= 250` lines each).
5. **Run all repository checks:**
   - `python3 tools/specs-lint.py --self-test && python3 tools/specs-lint.py`
   - `python3 tools/docs-lint.py`
   - `python3 tools/identifier-check.py --self-test && python3 tools/identifier-check.py`
   - `python3 .agents/hooks/guardrails.py --self-test`
6. **Commit and open PR:**
   - Commit the spec sync (`<area>: sync canonical specs for <slug>`) with a Linear magic-word trailer (`Closes STAT-<N> (<title>)` when merging finishes the issue, or `Part of STAT-<N> (<title>)` if more PRs remain).
   - Push the branch and open one ready-for-review PR using `.github/pull_request_template.md` (`Closes <ID>: <title>` or `Part of <ID>: <title>` on line 1).
   - Leave auto-merge OFF if the PR touches canonical `specs/`, `.agents/`, `platform/`, or CI.
   - Post a 4 to 6 line handoff on the Linear issue and report to the General using `stator-presenting`.
