---
title: Stator specs index
updated: 2026-11-24
---

# Stator specs

`specs/` is Stator's canonical truth in Git. Every agent starts here and loads only the slices needed for its task, keeping each session well inside a 200k-token context window.

## Canonical specs

| Spec | Covers |
|---|---|
| [DOMAIN.md](DOMAIN.md) | Real infrastructure orgs, 2-account AWS topology, logical environments, simulated teams, and labs-to-platform graduation |
| [GLOSSARY.md](GLOSSARY.md) | Ubiquitous Language: canonical terms, roles, entities, and banned vague synonyms |
| [INVARIANTS.md](INVARIANTS.md) | Seven non-negotiable rules, Tier 2 triggers, five-stage automation pipeline, and AWS/session boundaries |
| [STACK.md](STACK.md) | Verified free-tier limits (Nov 2026) and operational guardrails for GitHub, Cloudflare, AWS, and Supabase |
| [STRATEGY.md](STRATEGY.md) | North star, foundation-first model, named execution Tracks, and General vs squads command split |
| [SYSTEM.md](SYSTEM.md) | Stator operating system: General and squads model, Elephant-Goldfish gate, delta loop, and linter rules |

## Active changes

In-flight proposals live under `specs/changes/<slug>/` (`proposal.md` and `tasks.md`). When a change ships, its deltas merge into canonical `specs/` and `specs/changes/<slug>/` is deleted (`git log` is the archive).

## Rules (enforced by `tools/specs-lint.py`)

1. Keep every file in `specs/` at or below 200 lines.
2. Link every canonical spec file under `specs/` (except `specs/changes/`) from this index.
3. Keep every relative link in `specs/` valid.
4. Require every active `specs/changes/<slug>/` folder to carry explicit deltas and task Context Manifests.
