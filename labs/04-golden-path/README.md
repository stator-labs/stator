---
lab: "04"
title: "Golden Path"
status: idea
effort: "2 weekends"
cost_estimate: "~$0"
cost_spent: 0
roles: [Platform]
---

# Lab 04 · Golden Path

**Proof:** _not yet_

## Scenario
A new service currently takes two weeks to reach production because every repo starts from copy-paste and misses security or cost guardrails. Platform needs to cut time-to-first-deploy to one day.

## Requirements
- **Functional:** self-service template or CLI scaffolding a repo, CI pipeline, OIDC identity, SLO definitions and cost tags, with time-to-first-deploy measured.
- **SLO / reliability:** generated repos pass `docs-lint`, `tofu test` and CI checks on first push.
- **Cost ceiling:** `~$0` idle and per scaffold run.
- **Security & compliance:** scaffolds least-privilege IAM, `CODEOWNERS` on trust paths and mandatory cost tags by default.

## What I built
_Planned:_
- Backstage template or small CLI
- Scaffolds pipeline, identity, SLOs and cost tags already wired in

## Cost receipt
| Spent | Idle | Teardown |
|---|---|---|
| — | — | — |

## Decisions
_None yet._

## What broke
_Nothing yet._

## What I'd change
_TBD._

**Target roles:** Platform
