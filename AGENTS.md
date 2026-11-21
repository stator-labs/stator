# AGENTS.md: rules for any AI agent working in this repo

You are working on **Stator** (see README.md). Yaaf owns it; you propose, he approves.

## Read first
1. The claude.ai Project doc `claude/runway-control-center.md` if you can reach it. Otherwise read `docs/how-this-works.md`.
2. The Linear issue you were given (workspace `yaaf-some`, team Stator, key `STAT`).
3. The README of the lab you're touching.

## Hard rules
- **Fresh project.** Don't bring in earlier experiments (Floci, Online Boutique, SpinKube, "Harborline") unless they bring a clearly argued benefit.
- **No phases, no ADRs.** Labs are independent. Record decisions inline in the lab README as short "Why not X?" paragraphs (2–4 sentences).
- **Airgap is not a requirement.** Angular/Node are not required.
- **Real AWS beats emulation.** AWS Emulator, kind and k3d are for the inner loop only.
- **When Yaaf says something is "not used" or "irrelevant", delete it.** Don't keep it "just in case".
- **$0 idle.** Everything you create in AWS is tagged `project=runway`, `lab=<nn>`, `runway:ephemeral=true|false` and has a teardown path.
- **Supply chain:** pin GitHub Actions by commit SHA and container images by digest. Never add a dependency without saying why.

## Human in the loop
Why, and what enforces it: [docs/human-in-the-loop.md](docs/human-in-the-loop.md). Card format: [`stator-presenting`](.claude/skills/stator-presenting/SKILL.md).
- **Tier 0 · Do:** reversible, private, free work: read, research, edit on a branch, run checks, comment in Linear. Report it in the handoff.
- **Tier 1 · Review:** repo changes go in a PR, opened ready for review (not draft).
  - **Only allow-listed files changed:** enable auto-merge on your own PR. The PR merges when the required checks pass. The allow-list: `docs/` (except `docs/how-this-works.md`, `docs/human-in-the-loop.md`, `docs/index.md` and `docs/radar.md`), `labs/*/README.md`, `templates/`, `README.md`.
  - **Anything else changed:** leave auto-merge off. Yaaf merges. The `Policy: trust paths` check runs from `main`'s copy of its workflow, so a PR cannot change it, and it fails a PR outside the allow-list that has auto-merge on.
  - Never enable auto-merge on a PR you did not open.
  - Never merge a PR directly, and never approve or review one. You act as Yaaf on GitHub, so your approval would count as his. `.claude/settings.json` denies both.
- **Tier 2 · Ask first.** Stop, post a **change card**, and wait for a yes. No answer means no. Any one of these is enough:
  - **AWS:** applying a stack or approving a deployment.
  - **Cost:** anything above $0, idle or per run.
  - **Trust:** IAM, OIDC, rulesets, environments, secrets, tokens, network, connectors, `.claude/settings.json`.
  - **Deletion:** resources, data, issues, scheduled tasks, branches with unmerged work.
  - **Public:** comments on someone else's PR, posts, published pages, emails.
  - **Scope:** work past the issue's **Done when**, more than one lab, more than ~300 changed lines, or a project-wide convention (this file, the skills, the pipeline, the setup script).
- **Tier 3 · Never:** AWS credentials in a session (AWS changes run in GitHub Actions with the Lab 00 OIDC role, or in Yaaf's terminal), running `make bootstrap`, disabling a guardrail, force-pushing `main`, approving your own deployment, enabling auto-merge on a PR outside the allow-list.
- A yes covers one exact change. New commits, a different plan or a different target need a new yes.
- Unsure of the tier? Treat it as Tier 2.

## Workflow
1. Branch from `main`, named by the [naming rules](#naming). Never push to `main`.
2. Keep the change scoped to the issue's **Done when**. Anything new you notice (a topic, tool, lab or goal) becomes a Linear issue with the `Idea` label, not work, however small. Going further is Tier 2 (scope).
   - The same failure after two fix attempts: stop and report it. Don't keep trying.
   - Say what you skipped or deferred, and why, in the handoff and the PR.
3. Before finishing:
   - update the lab README (Proof, Cost receipt, Decisions, What broke) and its frontmatter `status`, and keep the root README lab table in sync
   - run `python3 tools/docs-lint.py` and fix what it reports
   - hand off in a comment on the Linear issue (format in `stator-presenting`). Then move the issue to the right state.
   - open a PR with the template, named by the [naming rules](#naming). Its first line links the Linear issue.
4. Never mark a lab ✅ without a working proof. Record the first failed run in "What broke"; don't rerun until green and hide it.

## Cloud sessions
- The Cloud-Project environment runs `tools/cloud-setup.sh` (pinned, SHA256-checked tools). Bump a version and its hash together, then paste the file into the environment's setup script.
- A cloud session starts on a generated `claude/<words>` branch. Don't use it: push to a branch named by the [naming rules](#naming). The session cannot delete branches; merged branches delete themselves.
- Docker doesn't start on its own. Run `dockerd &` first.
- Open PRs with `gh api repos/stator-labs/stator/pulls`. `gh pr` uses GraphQL, which the proxy blocks.
- Never print or echo token variables.

## Naming
A name says what the thing is or does, and reads on its own. No codes, jokes or tool jargon in a name a person reads. An ID such as `STAT-14` never stands alone: write what it is first.

| Thing | Rule | Example |
|---|---|---|
| Branch | `<area>/<what-it-changes>`, lowercase with hyphens | `lab00/budget-alerts` |
| Area | `lab00`…`lab11`, `labd`, `platform`, `process` (rules, skills, workflow), `radar` | `radar/2026-11-22` |
| Commit subject | `<area>: <change, imperative>` | `lab00: add budget alerts` |
| PR title | `<Area> · <what it changes>`, no issue ID | `Lab 00 · Budget alerts at $5, $15 and $30` |
| PR link to Linear | first line of the description: `Linear: <issue title> (<ID>)` | `Linear: Budget alerts (STAT-9)` |
| Linear issue | the outcome in plain words | `Budget alerts at $5, $15 and $30` |
| Lab | title `NN · <Topic>`, folder `NN-<topic>`; the Linear project has the same title | `Lab 05 · AI Agent Sandboxing`, `labs/05-agent-sandboxing` |
| Workflow | one noun for what it covers; the file has the same name | `Infrastructure`, `infrastructure.yml` |
| CI check | `<Workflow>: <action>`, so checks group by workflow in the ruleset picker. A workflow with several required jobs has one `<Workflow>: required checks` job that the ruleset requires | `Infrastructure: plan` |
| Required check | runs on `pull_request`, `merge_group` and `push` to `main`, with no path filter on the workflow, so it always reports | `Docs: lint` |
| Scheduled task | `Stator · <what it does>` | `Stator · Weekly trend radar` |
| AWS resource | `runway-<purpose>`, plus the required tags | `runway-budget-5` |

Don't use Linear's `gitBranchName`: an issue number says nothing.

## Docs rules (no wiki sprawl)
- Lab knowledge goes in the lab's README. `docs/` is only for what spans several labs, with at most 8 files and 250 lines each.
- Never create session, meeting or status notes in the repo. Those belong in Linear and the PR.
- Replace instead of appending. Delete anything stale; git history is the archive.
- Full rules: `docs/index.md`.

## Writing and presenting
- **Writing:** [`stator-writing`](.claude/skills/stator-writing/SKILL.md) for every doc, PR, Linear issue, comment and scheduled-task prompt. Short sentences, numbers over adjectives, no em dashes in prose.
- **Presenting:** [`stator-presenting`](.claude/skills/stator-presenting/SKILL.md) for handoffs, PR descriptions and decisions. Result first, tables for comparisons, Mermaid when trust or structure changes, a change card for Tier 2.
