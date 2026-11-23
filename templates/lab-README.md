---
lab: "NN"
title: "<Name>"
status: idea        # idea | next | now | done
effort: "N weekends"
cost_estimate: "$X"
cost_spent: 0
roles: [Platform]   # SA, Platform, Cloud, SRE, Security, AI Infra, Defense
---

# Lab NN · <Name>

## Proof
Links to real AWS runs, screenshots, outputs, and how to reproduce (`make proof`). Keep open gaps explicit until status is `done`.

## Scenario
Who asks for this, why now, and what it costs them today (keep Scenario + Requirements under 25 lines).

## Requirements
- **Functional:** what the system must do.
- **SLO / reliability:** target and measurement, or why none applies.
- **Cost ceiling:** idle and per-run cap.
- **Security & compliance:** controls satisfied (for example CIS AWS Foundations or MITRE ATLAS).

## Constraints
Hard limits: budget, regions, free tier, tools, or team ownership.

## Design and alternatives
Architecture diagram (if trust boundaries or data flow matter) and what was built.

**Why not X?** 2–3 sentences per key choice.

## Threat model and security notes
Main failure or abuse paths, least-privilege boundaries, and what stops blast radius.

## Cost
| Estimate | Spent | Idle | Teardown |
|---|---|---|---|
| $0.00 | $0.00 | $0.00 | `make down` (verified by the reaper) |

## Operations
Runbook commands, alerts, dashboards, and who responds.

## Rollout and rollback
How changes ship safely and how to undo them cleanly.

## Acceptance and demo
What a reviewer checks in 5 minutes to verify the requirements hold.

## What broke
Real failures, how you found them, and any time an AI agent was wrong. Keep the first failure.

## What I'd change
With more time, at a real company, or at 10x scale.

**Target roles:** SA, Platform, Cloud, SRE, Security
