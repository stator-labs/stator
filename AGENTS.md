# AGENTS.md: rules for any AI agent working in this repo

You are working on **Runway** (see README.md). Yaaf owns it; you propose, he approves.

## Read first
1. The claude.ai Project doc `claude/runway-control-center.md` if you can reach it. Otherwise read `kb/how-this-works.md`.
2. The Linear issue you were given (workspace `yaaf-some`, team `YAA`, which may be renamed `RUN`).
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
Why, and what enforces it: [kb/human-in-the-loop.md](kb/human-in-the-loop.md). Card format: [`runway-presenting`](.claude/skills/runway-presenting/SKILL.md).
- **Tier 0 · Do:** reversible, private, free work: read, research, edit on a branch, run checks, comment in Linear. Report it in the handoff.
- **Tier 1 · Review:** repo changes go in a PR, opened ready for review (not draft).
  - **No trust path touched:** enable auto-merge. The PR merges when the required checks pass.
  - **Trust path touched:** leave auto-merge off. Yaaf merges. Trust paths: `.github/`, `.claude/`, `AGENTS.md`, `CLAUDE.md`, `tools/`, `platform/infra/bootstrap/`, and any `.tf` change that adds or removes an `aws_iam_*` or `aws_organizations_*` line. The `kb-check` job fails a trust-path PR that has auto-merge on.
  - Never merge a PR directly.
- **Tier 2 · Ask first.** Stop, post a **change card**, and wait for a yes. No answer means no. Any one of these is enough:
  - **AWS:** applying a stack or approving a deployment.
  - **Cost:** anything above $0, idle or per run.
  - **Trust:** IAM, OIDC, rulesets, environments, secrets, tokens, network, connectors, `.claude/settings.json`.
  - **Deletion:** resources, data, issues, scheduled tasks, branches with unmerged work.
  - **Public:** comments on someone else's PR, posts, published pages, emails.
  - **Scope:** work past the issue's **Done when**, more than one lab, more than ~300 changed lines, or a project-wide convention (this file, the skills, the pipeline, the setup script).
- **Tier 3 · Never:** AWS credentials in a session (AWS changes run in GitHub Actions with the Lab 00 OIDC role, or in Yaaf's terminal), running `make bootstrap`, disabling a guardrail, force-pushing `main`, approving your own deployment, enabling auto-merge on a trust-path PR.
- A yes covers one exact change. New commits, a different plan or a different target need a new yes.
- Unsure of the tier? Treat it as Tier 2.

## Workflow
1. Branch from `main` as `<area>/<topic>`, for example `lab00/budgets` or `cc/naming`. Area is `lab00`…`lab11`, `labd`, `platform`, `radar` (weekly radar tasks, branch `radar/YYYY-MM-DD`) or `cc` (control center). Don't use Linear's `gitBranchName`: an issue number says nothing. Never push to `main`.
2. Keep the change scoped to the issue's **Done when**. Anything new you notice (a topic, tool, lab or goal) becomes a Linear issue with the `Idea` label, not work, however small. Going further is Tier 2 (scope).
   - The same failure after two fix attempts: stop and report it. Don't keep trying.
   - Say what you skipped or deferred, and why, in the handoff and the PR.
3. Before finishing:
   - update the lab README (Proof, Cost receipt, Decisions, What broke) and its frontmatter `status`, and keep the root README lab table in sync
   - run `python3 tools/kb-check.py` and fix what it reports
   - hand off in a comment on the Linear issue (format in `runway-presenting`). Then move the issue to the right state.
   - open a PR with the template, titled `<Area> · <plain name> (<issue ID>)`, for example `Lab 00 · Budget alerts (YAA-9)`. The ID at the end links the PR to Linear. Commit subjects start with the area: `lab00: add budget alerts`.
4. Never mark a lab ✅ without a working proof. Record the first failed run in "What broke"; don't rerun until green and hide it.

## Cloud sessions
- The Cloud-Project environment runs `tools/cloud-setup.sh` (pinned, SHA256-checked tools). Bump a version and its hash together, then paste the file into the environment's setup script.
- A cloud session can push only to the branch the session was given. Use it instead of `<area>/<topic>`, and name the PR as usual. The session cannot delete branches; merged branches delete themselves.
- Docker doesn't start on its own. Run `dockerd &` first.
- Open PRs with `gh api repos/yaaf-some/cloud-project/pulls`. `gh pr` uses GraphQL, which the proxy blocks.
- Never print or echo token variables.

## Knowledge-base rules (no wiki sprawl)
- Lab knowledge goes in the lab's README. `kb/` is only for what spans several labs, with at most 8 files and 250 lines each.
- Never create session, meeting or status notes in the repo. Those belong in Linear and the PR.
- Replace instead of appending. Delete anything stale; git history is the archive.
- Full rules: `kb/index.md`.

## Writing and presenting
- **Writing:** [`runway-writing`](.claude/skills/runway-writing/SKILL.md) for every doc, PR, Linear issue, comment and scheduled-task prompt. Short sentences, numbers over adjectives, no em dashes in prose.
- **Presenting:** [`runway-presenting`](.claude/skills/runway-presenting/SKILL.md) for handoffs, PR descriptions and decisions. Result first, tables for comparisons, Mermaid when trust or structure changes, a change card for Tier 2.
