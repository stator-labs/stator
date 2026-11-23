---
lab: "03"
title: "Ephemeral EKS Clusters"
status: idea
effort: "2–3 weekends"
cost_estimate: "$1–3/session"
cost_spent: 0
roles: [Platform, SRE]
---

# Lab 03 · Ephemeral EKS Clusters

**Proof:** _not yet_

## Scenario
Developers want a full preview environment per pull request without leaving idle clusters running overnight. Today clusters built by hand drift and stay billed after testing ends.

## Requirements
- **Functional:** provision EKS Auto Mode, Gateway API and Argo CD app-of-apps with `make up` / `make down`, plus `ingress2gateway` migration notes.
- **SLO / reliability:** preview environment ready in 20 minutes and torn down automatically by the nightly reaper (`make nuke`).
- **Cost ceiling:** `$1–3/session`, tracked per environment-hour and `$0` idle.
- **Security & compliance:** OIDC-only deploy, external port scan proving only intended ports are exposed, mandatory ephemeral tags.

## What I built
_Planned:_
- EKS Auto Mode + Gateway API + Argo CD app-of-apps
- `make up` / `make down`
- ingress-nginx → Gateway API migration with ingress2gateway, plus what it didn't translate

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

**Target roles:** Platform, SRE
