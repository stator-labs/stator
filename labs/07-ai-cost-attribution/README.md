---
lab: "07"
title: "AI Cost Attribution"
status: idea
effort: "2 weekends"
cost_estimate: "$2–10"
cost_spent: 0
roles: [Cloud, Platform, SA, AI Infra]
---

# Lab 07 · AI Cost Attribution

**Proof:** _not yet_

## Scenario
The AI bill tripled and finance wants cost split per team, agent and resolved ticket. Today model usage arrives as one opaque AWS Bedrock invoice with no team caps.

## Requirements
- **Functional:** place an AI gateway in front of Bedrock with per-team/agent keys, OpenTelemetry GenAI traces, a daily FOCUS-format export and a monthly showback report.
- **SLO / reliability:** per-team budgets stop overspend automatically without dropping healthy teams.
- **Cost ceiling:** `$2–10` experiment cap, `$0` idle when stopped.
- **Security & compliance:** gateway dependency review (after LiteLLM incidents), scoped API keys and tagged Bedrock calls.

## What I built
_Planned:_
- AI gateway in front of Bedrock with per-team/agent keys and budgets
- OpenTelemetry GenAI traces
- Daily FOCUS-shaped cost export, cost per resolved ticket
- Which gateway to trust after the LiteLLM incidents

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

**Target roles:** Cloud, Platform, SA, AI Infra
