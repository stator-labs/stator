---
lab: "02"
title: "Serverless vs Kubernetes Cost"
status: idea
effort: "2 weekends"
cost_estimate: "$5–15"
cost_spent: 0
roles: [SA, Cloud]
---

# Lab 02 · Serverless vs Kubernetes Cost

**Proof:** _not yet_

## Scenario
The CFO asks whether the catalog API should stay on Lambda as traffic grows. Today teams debate serverless versus containers with slides instead of real load and billing numbers.

## Requirements
- **Functional:** run the same catalog API on Lambda, Lambda Managed Instances and ECS/Fargate under k6 load at 1, 10 and 50 requests per second, plus a break-even chart and one-page decision memo.
- **SLO / reliability:** measure p95 latency at each load tier against the API target and record cold-start tails.
- **Cost ceiling:** `$5–15` total test budget, `$0` idle after teardown.
- **Security & compliance:** deploy via OIDC with mandatory `project`, `lab` and `ephemeral` cost tags.

## What I built
_Planned:_
- Same API on Lambda, Lambda Managed Instances and ECS/Fargate
- k6 at 1/10/50 rps
- Cost curve + a decision rule (tests AWS's ~9 rps claim)

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

**Target roles:** SA, Cloud
