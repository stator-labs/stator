---
lab: "11"
title: "Build vs Buy Analysis"
status: idea
effort: "1 weekend"
cost_estimate: "~$0"
cost_spent: 0
roles: [SA, Platform]
---

# Lab 11 · Build vs Buy Analysis

**Proof:** _not yet_

## Scenario
A per-seat SaaS contract (feature flags or status page) is up for renewal, and finance asks whether self-hosting saves money. Today comparisons ignore on-call, patching and upgrade toil.

## Requirements
- **Functional:** deploy an open-source replacement in the Stator stack, measure TCO including on-call and patching hours, produce a risk register and write a recommendation memo.
- **SLO / reliability:** self-hosted replacement meets availability expectations without paging on-call outside business hours.
- **Cost ceiling:** `~$0` idle during evaluation.
- **Security & compliance:** pinned OSS container digests, supply-chain scan and upgrade runbook.

## What I built
_Planned:_
- Replace one paid SaaS (feature flags or status page) with OSS
- TCO including on-call and patching

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

**Target roles:** SA, Platform
