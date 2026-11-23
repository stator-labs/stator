---
lab: "D"
title: "Disconnected Delivery (optional)"
status: idea
effort: "1–2 weekends"
cost_estimate: "~$0"
cost_spent: 0
roles: [Defense]
---

# Lab D · Disconnected Delivery (optional)

**Proof:** _not yet_

## Scenario
A customer or defense site has no internet access at install time. Today deployments assume live access to public registries and package repositories.

## Requirements
- **Functional:** package one Stator service as a Zarf bundle, install it in an environment with egress blocked, and emit a complete evidence bundle (SBOM, signatures, policy results).
- **SLO / reliability:** air-gapped install succeeds deterministically with zero external network calls.
- **Cost ceiling:** `~$0` idle (local/ephemeral validation).
- **Security & compliance:** signed artifacts, SBOM verification, policy check results and egress-blocked proof.

## What I built
_Planned:_
- One service as a Zarf package
- Deploy with egress blocked
- Evidence bundle: SBOM, signatures, policy results

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

**Target roles:** Defense
