---
title: Stator verified stack
updated: 2026-11-24
---

# Stator verified stack

Verified free-tier services and operational limits as of November 2026. Probe and re-verify limits before relying on any service outside these bounds.

| Service | Free-tier limit (Nov 2026) | Role in Stator | Key guardrail |
|---|---|---|---|
| **GitHub Actions** | Free on public repos (standard runners) | OIDC `tofu plan`/`apply`, reaper, collectors | Pin actions by full commit SHA; minimal per-job perms |
| **GitHub Agentic Workflows** (`github/gh-aw`) | Runs on GitHub Actions; pin `>= 0.85.4` | `.github/workflows/*.md` reasoned workflows | 3-container `awf` firewall + Safe Outputs schema |
| **Cloudflare Workers** | `100,000` req/day (UTC), `10 ms` CPU/req, unlimited static | Webhook ingest, dedup, `repository_dispatch` | Keep `< 10 ms` CPU; secrets via `wrangler secret` |
| **Cloudflare D1 / KV / Queues** | D1: `5M` reads/d, `100k` writes/d, `5 GB`, `10` DBs max; KV: `100k` R / `1k` W/D/L per day; Queues: `10k` ops/d, `24h` retention | Worker state, dedup caches, async queues | Never exceed `10` D1 DBs (`$0.10`/mo per extra DB) |
| **Cloudflare Pages** | Unlimited static reqs/bandwidth, `500` builds/month | Optional site host and live proof dashboard | Alternative or complement to Quartz (`STAT-17`) |
| **AWS (`Management` + `Labs`)** | `$0` idle baseline; first `2` action-enabled budgets free | Org/SCPs/trail/budgets in `Management`; labs in `Labs` | Native `job_workflow_ref` OIDC + `$30` kill-switch SCP |
| **Supabase** (optional) | `2` projects, `500 MB` DB, `1 GB` storage, `5 GB` egress (`+5 GB` cached), `50k` MAU, `500k` Edge calls/mo | Optional backend for `catalog-api` and `triage-agent` | Pauses after `1 week` idle; keep schema in Git |

## 1. GitHub Actions

- **Limits:** Free minutes on public repositories using standard GitHub-hosted runners.
- **Role:** Runs OIDC-authenticated OpenTofu plans on PRs, saved-plan applies on `main`, nightly resource checks (`reaper.yml`), and deterministic data collectors.
- **Guardrails:** Pin every action by full 40-character commit SHA and bump via [dependabot.yml](../.github/dependabot.yml) with a 7-day cooldown. Default workflow `permissions` to `read-all` or `{}` and grant minimum permissions per job. Derive the state bucket from the `AWS_LABS_ACCOUNT_ID` repo variable and pass it with `-backend-config` so no account ID sits in Git. Plan jobs get no secrets, and their scripts run from `main`, not the PR.

## 2. GitHub Agentic Workflows (`github/gh-aw`)

- **Limits and version pin:** Pin a reviewed `github/gh-aw` release `>= 0.85.4`. Releases from `0.83.3` up to `< 0.85.4` are retired due to a vulnerability.
- **Role:** Compiles markdown workflow specs (`.github/workflows/*.md`) via `gh aw compile` into `.lock.yml` and `.github/aw/actions-lock.json` for bounded reasoning jobs.
- **Guardrails:** Runs inside the 3-container `awf` firewall (Squid egress proxy, agent container, API-key sidecar) and restricts writes through Safe Outputs schema checks. Ignore `github/gh-aw-actions/*` in [dependabot.yml](../.github/dependabot.yml) so Dependabot does not conflict with `gh aw compile`.

## 3. Cloudflare Workers

- **Limits:** `100,000` requests/day (resets `00:00` UTC), `10 ms` CPU time per invocation, and unlimited static asset requests.
- **Role:** Receives external webhooks (for example Linear or digest feeds), deduplicates events, and triggers GitHub `repository_dispatch`.
- **Guardrails:** Keep execution under `10 ms` CPU time. Isolate bindings per `--env`, keep per-request state out of module globals, pass every background promise to `await` or `ctx.waitUntil`, and store secrets exclusively via `wrangler secret`.

## 4. Cloudflare D1 / KV / Queues

- **D1 limits:** `5M` row reads/day, `100k` row writes/day, `5 GB` total storage, and maximum `10` databases. Exceeding `10` databases bills `$0.10`/month even when empty.
- **KV limits:** `100k` reads/day and `1k` writes, deletes, or lists per day.
- **Queues limits:** `10k` operations/day with `24h` message retention.
- **Role and guardrails:** Store lightweight deduplication state and webhook buffers within free daily caps. Enforce the `<= 10` D1 database ceiling so idle cost stays `$0`.

## 5. Cloudflare Pages

- **Limits:** Unlimited static requests and bandwidth, capped at `500` builds/month.
- **Role:** Optional host for the simulated marketing site and live proof dashboard, complementing or substituting for Quartz on GitHub Pages (public proof site `STAT-17`).
- **Guardrails:** Keep builds under `500`/month by building only on `main` changes or scheduled publishes.

## 6. AWS (`Management` + `Labs` accounts)

- **Limits:** `$0` idle baseline. AWS grants the first `2` action-enabled budgets free, which covers Stator's `$5`, `$15`, and `$30` alerts plus the `$30` kill-switch SCP action.
- **Role:** `Management` holds the AWS Organization, guardrail SCPs, 90-day org CloudTrail, IAM Access Analyzer, Identity Center, and budgets. `Labs` (`runway-labs` in `stator-labs` OU) runs CI (`stator-ci-plan-pr`, `stator-ci-plan-main`, `stator-ci-apply`, `stator-ci-reaper`) and ephemeral lab stacks.
- **Guardrails:** Use native IAM `job_workflow_ref` conditions and GitHub `sub` claim customization (no static IAM keys). Enforce `default_tags` (`project`, `lab`, `ephemeral` or `runway:ephemeral`) with Checkov and commit `.terraform.lock.hcl` for `linux_amd64` and `darwin_arm64`. See [platform/infra/README.md](../platform/infra/README.md).

## 7. Supabase (optional for app labs)

- **Limits:** `2` active projects, `500 MB` Postgres (switches to read-only at `95%` of `2 GB` disk), `1 GB` file storage, `5 GB` uncached egress (`+ 5 GB` cached egress), `50k` monthly active Auth users, and `500k` Edge Function invocations/month.
- **Role:** Optional managed Postgres, Auth, and audit-trail backend for simulated company apps (`catalog-api` and `triage-agent`) using Row Level Security.
- **Guardrails:** Free projects pause after `1 week` of inactivity and include no automatic backups. Keep all SQL schemas, migrations, and seed scripts in Git so every lab rebuilds cleanly from scratch.
