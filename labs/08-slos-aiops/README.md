---
lab: "08"
title: "SLOs and Governed AIOps"
status: idea
effort: "2 weekends"
cost_estimate: "~$0"
cost_spent: 0
roles: [SRE]
---

# Lab 08 · SLOs and Governed AIOps

**Proof:** _not yet_

## Scenario
On-call is burning out from noisy symptom alerts while unreviewed AI ops tools risk making outages worse. SRE needs signal-based paging and safe remediation.

## Requirements
- **Functional:** OTel collector, Prometheus/Grafana dashboards, SLO burn-rate alerts linked to runbooks, and a read-only triage agent that proposes fixes as PRs a human approves, with time to restore measured.
- **SLO / reliability:** multi-window burn-rate alerts catch budget exhaustion early with low false-positive paging.
- **Cost ceiling:** `~$0` idle (ephemeral lab stack).
- **Security & compliance:** triage agent holds read-only telemetry access and opens PRs under `stator-bot` with human merge approval.

## What I built
_Planned:_
- OTel collector, Prometheus/Grafana, SLO burn-rate alerts
- Read-only triage agent proposes a PR; a human approves

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

**Target roles:** SRE
