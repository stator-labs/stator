---
title: Stator strategy
updated: 2026-11-24
---

# Stator strategy

Stator separates long-term direction from tactical lab work so every PR stays small, verifiable, and safe. See [GLOSSARY.md](GLOSSARY.md) for canonical terms and [SYSTEM.md](SYSTEM.md) for the four-stage operating loop.

## North star

Turn chaotic, manual, risky cloud and AI setups into boring, self-service, `$0`-idle platforms in public. Each lab proves depth across Solutions Architecture, Platform Engineering, Cloud, SRE, Security, AI Infrastructure, and Defense delivery using real AWS receipts rather than slideware.

## Foundation-first, then modular labs

- **Lab 00 is the hard prerequisite:** Account Foundation ([README.md](../README.md)) establishes the AWS Organization, SCP guardrails, OIDC CI/CD without static keys, remote state, budgets, kill switch, and one-command teardown. All subsequent labs depend on this boundary (see `INVARIANTS.md`).
- **Standalone composable labs:** Labs 01 to 11 and optional Lab D stand alone and can run in any order after Lab 00.
- **No ADRs, no phase gates:** Labs record tradeoffs inline as short "Why not X?" notes (2 to 3 sentences) rather than separate ADR files or rigid numbered project phases.

## Named execution tracks

Stator organizes ongoing work into four named **Tracks**. Active execution status, priorities, and timelines live in Linear `Roadmap · Execution tracks and rebuilt scheduled automation` (`P-STAT-1`).

| Track | Scope |
|---|---|
| **Track 1** | Account and OIDC security foundation (`Management`, `Labs`, OIDC, remote state, budgets, `$30` kill switch). |
| **Track 2** | Exception-based human-in-the-loop (HITL) controls and Lab 00 closeout. |
| **Track 3** | Deterministic automation and re:Invent ingestion. |
| **Track 4** | Simulated 30-engineer company across Labs 01 to 11 and Lab D. |

## Command split

Stator divides strategic ownership from tactical execution (detailed in [SYSTEM.md](SYSTEM.md)):

- **General (Yaaf):** Sets strategy and track priorities, answers design interviews, approves canonical `specs/` changes, and decides Tier 2 risks (AWS applies, spend above `$0`, trust changes, deletions, public posts, and cross-lab scope).
- **Squads (AI agents):** Draft vetted change proposals (`stator-elephant`), run zero-context reviews (`stator-goldfish`), execute atomic tasks in fresh contexts (`stator-execute`), and sync canonical specs (`stator-living-docs`) on branches and pull requests.
