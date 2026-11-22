---
title: Stator docs
updated: 2026-11-22
---

# Stator docs

Plain Markdown. Renders cleanly on GitHub, mobile, Obsidian or any editor.

## Index
- [how-this-works](how-this-works.md): board, automation loop, cost guardrails.
- [human-in-the-loop](human-in-the-loop.md): risk tiers, two-lane HITL flow and enforcement map.
- [bot-identity](bot-identity.md): `stator-bot` GitHub App setup (`CODEOWNERS`, Merge Queue, short-lived tokens).
- [radar](radar.md): watched trends and tools (max 25 rows).
- [research/2026-11-runway-report](research/2026-11-runway-report.md): baseline research report.

Lab knowledge lives in each lab's `labs/NN-*/README.md`. The full lab list sits in the [root README](../README.md).

## Rules (enforced by `tools/docs-lint.py`)
1. **Stay local:** lab specifics belong in `labs/NN-*/README.md`; `docs/` holds cross-lab docs only.
2. **Hard cap:** at most 8 files in `docs/` and 250 lines per file.
3. **No orphans:** every file in `docs/` must be linked from this page.
4. **Radar cap:** one table, max 25 rows. Move adopted items to a lab README; delete dropped ones.
5. **Replace, don't append:** delete stale text; `git log` is the archive.
6. **No status notes in git:** handoffs live on the Linear issue and PR.
