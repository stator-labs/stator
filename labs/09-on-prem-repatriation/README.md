---
lab: "09"
title: "On-Premises Repatriation"
status: idea
effort: "2–3 weekends"
cost_estimate: "~$0"
cost_spent: 0
roles: [Platform, SA, Defense]
---

# Lab 09 · On-Premises Repatriation

**Proof:** _not yet_

## Scenario
The steady-state catalog API may cost more in the cloud than on rented bare metal or colo hardware. Platform needs real deployment numbers and a migration plan before committing to repatriation.

## Requirements
- **Functional:** run Stator on local k3s/Talos with a KubeVirt VM workload, CloudNativePG, a cloud-vs-colo TCO memo and a data migration plan with RPO and RTO.
- **SLO / reliability:** stated RPO/RTO bounds for Postgres migration cutover with verified service health.
- **Cost ceiling:** `~$0` AWS spend (local cluster evaluation).
- **Security & compliance:** local network isolation, declarative cluster manifests and reproducible image digests.

## What I built
_Planned:_
- Stator on local k3s/Talos
- KubeVirt VM workload + CloudNativePG
- Cloud-vs-colo TCO memo for the steady-state API

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

**Target roles:** Platform, SA, Defense
