---
lab: "10"
title: "Backup and Disaster Recovery"
status: idea
effort: "1–2 weekends"
cost_estimate: "<$3"
cost_spent: 0
roles: [SRE]
---

# Lab 10 · Backup and Disaster Recovery

**Proof:** _not yet_

## Scenario
A customer contract requires proof of database restore within stated RPO and RTO targets. Today backups run without tested recovery drills or off-account copies.

## Requirements
- **Functional:** ship CloudNativePG backups to S3 (with off-account copy), break the database on purpose, complete a timed restore drill against RPO/RTO and write a blameless postmortem.
- **SLO / reliability:** timed restore meets the stated RPO and RTO targets under real failure conditions.
- **Cost ceiling:** `<$3` total test budget, `$0` idle after teardown.
- **Security & compliance:** encrypted off-account backup target, least-privilege backup role and audit trail.

## What I built
_Planned:_
- CloudNativePG backups to S3
- Break things on purpose; restore against stated RPO/RTO
- Blameless postmortem

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
