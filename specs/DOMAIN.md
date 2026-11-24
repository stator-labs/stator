---
title: Stator domain model
updated: 2026-11-24
---

# Stator domain model

Stator platforms and governs a simulated 30-engineer company on real AWS at `$0` idle. This spec defines the real infrastructure orgs, AWS account topology, logical environments, simulated teams, and how labs graduate into the shared platform. See [GLOSSARY.md](GLOSSARY.md) for canonical terms.

## Real infrastructure orgs

Stator operates across four real accounts and organizations:

| Infrastructure org | Scope |
|---|---|
| **AWS Organization** | `Management` account plus the `stator-labs` organizational unit (OU) holding the `Labs` account (`runway-labs`). See [platform/infra/README.md](../platform/infra/README.md). |
| **GitHub (`stator-labs`)** | Source repository, GitHub Actions CI/CD, OIDC federation, rulesets, and PR gates. |
| **Cloudflare** | Free-tier account for webhook ingestion, Workers, D1/KV/Queues, and optional static hosting (limits in `STACK.md`). |
| **Linear (`yaaf-some`)** | Team `Stator` (`STAT`) tracking active issues, priorities, and `Roadmap` execution status. |

## AWS topology and logical environments

Stator keeps a lean 2-account AWS topology (`Management` + `Labs`) at `$0` idle under a single `$30` monthly kill-switch boundary. Add a third AWS account only when a specific lab proves one is required.

Instead of separate staging or production AWS accounts, Stator models three logical **environments**:

- **`local`:** Inner-loop emulation on a workstation or runner using `kind`, `k3d`, and AWS Emulator. Real AWS always beats emulation for final proof.
- **`ephemeral`:** Per-lab or per-session real AWS stacks in `Labs` with mandatory tags and one-command teardown back to `$0` idle.
- **`shared-platform`:** Persistent `$0`-idle foundation across `Management` and `Labs` (organization SCPs, OIDC identity providers, remote OpenTofu state, CloudTrail, and budgets).

## Simulated company and teams

Stator models a fictional 30-engineer Los Angeles company replacing manual deployments, static AWS keys, and unattributed AI spend with a boring, self-service platform. See [README.md](../README.md) for the scenario diagram and lab list.

Four **simulated teams** own the platform and workloads:

| Simulated team | Owns |
|---|---|
| **`platform`** | Golden paths, EKS and Lambda base modules, GitOps, CI/CD, and observability. |
| **`commerce`** | `site` (marketing site and quote form), `catalog-api` (catalog and orders API), and the nightly `batch` job. |
| **`ai-support`** | `triage-agent` (support-triage AI agent), Bedrock and AI gateway usage, agent sandboxes, and evals. |
| **`security-finops`** | SCPs, supply-chain gates, non-human identity and audit, budgets, anomaly detection, and cost attribution. |

## Mechanical team enforcement

Team boundaries rely on automated checks rather than prose rules:

- **AWS tags:** Simulated workload stacks set a `team` tag alongside mandatory `project`, `lab`, and `ephemeral` (or `runway:ephemeral`) tags.
- **State prefixes:** OpenTofu stacks store state under distinct per-lab or platform prefixes in S3.
- **Kubernetes namespaces:** Workloads run in isolated per-team namespaces.
- **Code ownership:** GitHub `CODEOWNERS` maps repository paths to owning teams.
- **Per-team budgets:** Cloud and AI gateway budgets track and cap spend per team.

## Labs-to-platform graduation

Each **lab** (`labs/NN-*/`) proves one capability standalone with real AWS output, a **cost receipt**, inline "Why not X?" decisions, and "What broke". When a module or GitOps pattern becomes reusable across labs, it graduates into `platform/`. Workloads live in `apps/`.
