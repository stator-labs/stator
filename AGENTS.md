# AGENTS.md: rules for any AI agent working in Stator

Yaaf owns Stator (see `README.md`). You propose; he approves real risk.

## Read first
1. `specs/INDEX.md` and `specs/GLOSSARY.md` (load only the spec slices needed for your task: `DOMAIN.md`, `STRATEGY.md`, `INVARIANTS.md`, `STACK.md`, `SYSTEM.md`).
2. Linear `Roadmap · Execution tracks and rebuilt scheduled automation` (`P-STAT-1`) for active execution order, plus `docs/how-this-works.md`.
3. Your Linear issue (workspace `yaaf-some`, team `Stator`, key `STAT`).
4. The README of the lab you're touching.

## Hard rules
- **Fresh project.** Don't import old experiments (Floci, Online Boutique, SpinKube, "Harborline") without a clear reason.
- **Foundation-first, no ADRs.** Lab 00 is the prerequisite; Labs 01 to 11 + D stand alone. Use named Tracks (not phases) and record choices inline as short "Why not X?" notes (2–3 sentences).
- **Real AWS beats emulation.** AWS Emulator, kind and k3d are inner-loop only.
- **Delete what Yaaf drops.** Never keep "just in case".
- **$0 idle.** Tag every AWS resource (`project`, `lab`, `ephemeral`) and give it a teardown path.
- **Supply chain:** pin GitHub Actions by commit SHA and images by digest. Explain every new dependency.

## Writing and tone
Follow [`.agents/skills/stator-writing/SKILL.md`](.agents/skills/stator-writing/SKILL.md) (Orwell's six rules) and [`.agents/skills/stator-presenting/SKILL.md`](.agents/skills/stator-presenting/SKILL.md) everywhere: docs, PRs, tickets, comments and chat replies.
- Write like a human teammate. Cut filler. Short sentences. Numbers beat adjectives.
- Never repeat empty fields ("Cost: $0", "Security: None", "Skipped: Nothing").
- No em dashes in prose.

## Human in the loop
Why and what enforces it: [docs/human-in-the-loop.md](docs/human-in-the-loop.md).
- **Tier 0 · Do:** read, research, edit on a branch, run local checks, comment in Linear.
- **Tier 1 · PR:** open ready for review (not draft).
  - **Allow-listed files only:** enable auto-merge on your own PR. Allow-list: `docs/` (except `docs/how-this-works.md`, `docs/human-in-the-loop.md`, `docs/index.md`, `docs/radar.md`), `labs/*/README.md`, `templates/`, `README.md`.
  - **Anything else:** leave auto-merge off. Canonical `specs/` files stay human-reviewed; tactical execution inside an approved proposal runs autonomously by squads. `Policy: trust paths` enforces this from `main`.
  - Never merge, review or approve a PR. `.agents/hooks/guardrails.py` blocks both.
- **Tier 2 · Ask first:** stop, send a short risk ask (`.agents/skills/stator-presenting/SKILL.md`), and wait for a yes. Triggers:
  - **AWS:** applying a stack or approving a deployment.
  - **Cost:** anything above $0, idle or per run.
  - **Trust:** IAM, OIDC, rulesets, environments, secrets, tokens, network, `.agents/hooks*`.
  - **Deletion:** resources, data, issues, schedules, unmerged branches.
  - **Public:** comments on others' PRs, posts, emails.
  - **Scope:** work past **Done when**, >1 lab, >~300 changed lines, or repo-wide rules/pipelines.
- **Tier 3 · Never:** AWS credentials in an agent session, running `make bootstrap`, disabling a guardrail, force-pushing `main`, approving your own deploy, or auto-merging outside the allow-list.
- A yes covers one exact change. Unsure of the tier? Treat it as Tier 2.

## Workflow
1. Branch from `main` using the naming rules below. Never push to `main`.
2. For non-trivial changes, run the OS loop (`stator-elephant` -> `stator-goldfish` -> `stator-execute` -> `stator-living-docs`).
3. Stay inside the issue's **Done when**. Log anything new as a Linear `Idea` issue. Same failure twice: stop and report.
4. Before finishing:
   - update the lab README (Proof, Cost receipt, Decisions, What broke) and keep the root README table in sync
   - run `python3 tools/specs-lint.py`, `python3 tools/docs-lint.py`, and `python3 tools/identifier-check.py`
   - post a short handoff (4–6 lines) on the Linear issue and update its state
   - open a PR using `.github/pull_request_template.md`, linking the Linear issue on line 1
5. Never mark a lab ✅ without real proof. Keep the first failure in "What broke".

## Cloud sessions
- Cloud VMs run `tools/cloud-setup.sh` or `tools/antigravity-setup.sh` (shared SHA256 pins).
- Push to a properly named branch, not an auto-generated one.
- Open PRs with `gh api repos/stator-labs/stator/pulls` (`gh pr` uses GraphQL).
- Never echo token variables.

## Naming
Plain words that read on their own. Never use a bare issue ID: write what it is first ("budget alerts (STAT-9)").

| Thing | Rule | Example |
|---|---|---|
| Branch | `<area>/<what-it-changes>` | `lab00/budget-alerts` |
| Area | `lab00`…`lab11`, `labd`, `platform`, `process`, `radar` | `radar/2026-11-22` |
| Commit | `<area>: <change, imperative>` | `lab00: add budget alerts` |
| PR title | `<Area> · <what it changes>` (no issue ID) | `Lab 00 · Budget alerts at $5, $15 and $30` |
| PR link | Line 1: `Linear: <title> (<ID>)` | `Linear: Budget alerts (STAT-9)` |
| Lab | `NN · <Topic>`, folder `NN-<topic>` | `Lab 05 · AI Agent Sandboxing` |
| Workflow | One noun, matching filename | `Infrastructure`, `infrastructure.yml` |
| CI check | `<Workflow>: <action>` | `Infrastructure: plan` |
| AWS resource | `stator-<purpose>` (legacy management: `runway-*`) | `stator-plan` |

## Docs rules (no wiki sprawl)
- Lab knowledge lives in `labs/NN-*/README.md`. `docs/` holds cross-lab docs only (<= 8 files, <= 250 lines each).
- No session, meeting or status notes in git. Replace instead of appending. Full rules: `docs/index.md`.
