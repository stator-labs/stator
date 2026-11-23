---
lab: "05"
title: "AI Agent Sandboxing"
status: idea
effort: "2–3 weekends"
cost_estimate: "$1–3/session"
cost_spent: 0
roles: [Platform, Security, AI Infra]
---

# Lab 05 · AI Agent Sandboxing

**Proof:** _not yet_

## Scenario
Support wants an agent that runs code on tickets, while security says untrusted code must never reach customer data or AWS credentials. Today an agent with tools carries an uncontained blast radius.

## Requirements
- **Functional:** run the triage agent in a sandboxed runtime (OpenShell locally, Nitro Sandboxes on EKS `isolated-sandbox`) with deny-by-default egress and credential placeholders.
- **SLO / reliability:** red-team probes trigger policy denials deterministically and a kill switch stops runaway sandboxes immediately.
- **Cost ceiling:** `$1–3/session`, `$0` idle after teardown.
- **Security & compliance:** threat model mapped to MITRE ATLAS, strict egress allow-list and recorded policy denials.

## What I built
_Planned:_
- Triage agent in OpenShell locally (deny-by-default egress, credential placeholders)
- Nitro Sandboxes on EKS (`runtimeClassName: isolated-sandbox`)
- Red-team it and record the policy denials

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

**Target roles:** Platform, Security, AI Infra
