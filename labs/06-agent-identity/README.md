---
lab: "06"
title: "AI Agent Identity and Audit"
status: idea
effort: "2–3 weekends"
cost_estimate: "$1–3/session"
cost_spent: 0
roles: [Security, Platform, SA]
---

# Lab 06 · AI Agent Identity and Audit

**Proof:** _not yet_

## Scenario
Auditors ask which agent did what, on whose behalf. Today agents borrow human or shared credentials, leaving no traceable chain from ticket to tool call.

## Requirements
- **Functional:** per-agent identity (EKS Pod Identity + SPIFFE/SPIRE), MCP tool server requiring scoped short-lived OAuth tokens, and an immutable agent-to-human-to-policy audit trail.
- **SLO / reliability:** unauthenticated or over-scoped tool calls reject deterministically with zero credential leakage.
- **Cost ceiling:** `$1–3/session`, `$0` idle after teardown.
- **Security & compliance:** NIST agent-identity tenets and MCP auth specification alignment, plus least-privilege data isolation.

## What I built
_Planned:_
- EKS Pod Identity for services
- SPIFFE/SPIRE IDs for agents
- MCP tool server requiring scoped short-lived OAuth
- Audit trail agent → human → policy, mapped to NIST agent-identity tenets

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

**Target roles:** Security, Platform, SA
