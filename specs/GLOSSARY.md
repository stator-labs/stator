---
title: Stator glossary
updated: 2026-11-24
---

# Stator glossary (Ubiquitous Language)

Use these exact terms across specs, code, tickets, PRs, and agent prompts. If a term changes, update this file in the same PR.

## Roles and operating system

| Term | Meaning |
|---|---|
| **General** | Yaaf. Owns strategy, approves canonical `specs/` changes, and decides Tier 2 risks. Delegates tactical execution to squads. |
| **Squad** | One or more fresh-context AI workers executing atomic tactical tasks inside an approved change proposal. |
| **Elephant** | Context-rich design session that interviews the General and writes `specs/changes/<slug>/`. Writes no implementation code. |
| **Goldfish** | Stateless, zero-context reviewer subagent that audits a proposal using only `specs/` and referenced code. |
| **Canonical spec** | Living truth under `specs/` (excluding `specs/changes/`). Requires General review before merge. |
| **Change proposal** | Active folder `specs/changes/<slug>/` holding `proposal.md` (with `ADDED`, `MODIFIED`, `REMOVED`, `RENAMED` deltas) and `tasks.md`. Deleted on merge. |
| **Context manifest** | Explicit list of up to 12 files a fresh-context worker reads for one atomic task, keeping work well inside 200k tokens. |

## Domain and delivery

| Term | Meaning |
|---|---|
| **Lab** | Standalone engineering proof in `labs/NN-*/` with a proof, cost receipt, inline "Why not X?" decisions, and "What broke". |
| **Platform** | Reusable OpenTofu modules and GitOps config in `platform/` that labs graduate into. |
| **Workload** | Simulated LA company app in `apps/`: marketing site, catalog/orders API, nightly batch job, or support-triage AI agent. |
| **Cost receipt** | Measured real AWS spend for running and tearing down a lab, recorded in the lab README. |
| **Tier 0 / 1 / 2 / 3** | Stator's risk tiers in [human-in-the-loop](../docs/human-in-the-loop.md): Do, PR, Ask first, Never. |
| **Infrastructure org** | Real platform or cloud organization Stator operates in (AWS Organization `Management` + `stator-labs` OU, GitHub org `stator-labs`, Cloudflare account, Linear workspace `yaaf-some`). |
| **Simulated company** | The fictional 30-engineer LA company whose services and AI agents Stator platforms and governs. |
| **Simulated team** | One of four internal teams (`platform`, `commerce`, `ai-support`, `security-finops`) isolated by tags, state prefixes, namespaces, `CODEOWNERS`, and budgets. |
| **Environment** | Logical execution tier (`local`, `ephemeral`, or `shared-platform`) inside Stator's 2-account AWS topology rather than separate accounts per stage. |
| **Track** | Named execution sequence (Tracks 1 to 4) replacing the deprecated "Phase" label; execution status lives in Linear `Roadmap`. |

## Avoid these vague terms

| Do not write | Write instead |
|---|---|
| ticket, RFC, plan doc (for spec work) | **Change proposal** |
| wiki, master doc, source doc | **Canonical spec** |
| sanity check, vibe check | **Goldfish review** |
| agent swarm (generic) | **Squad** |
| file list, reading list | **Context manifest** |
| Phase | **Track** |
| tenant (for internal teams) | **Simulated team** |
| staging/prod account (under 2-account model) | **Environment** |
