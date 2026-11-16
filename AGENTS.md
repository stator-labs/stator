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
- **No AWS credentials in agent sessions.** Changes to real AWS go through GitHub Actions using the Lab 00 OIDC role, or through Yaaf's own terminal.
- **$0 idle.** Everything you create in AWS is tagged `project=runway`, `lab=<nn>`, `runway:ephemeral=true|false` and has a teardown path.
- **Supply chain:** pin GitHub Actions by commit SHA and container images by digest. Never add a dependency without saying why.

## Human in the loop
Full rules: [kb/human-in-the-loop.md](kb/human-in-the-loop.md). In short:
- **Tier 0 · Do:** reversible, private, free work. Report it in the handoff.
- **Tier 1 · Review:** repo changes go in a PR. **Never merge.** Yaaf merges.
- **Tier 2 · Ask first:** AWS changes, any cost, IAM/trust/secrets/settings, deletions, anything public, or more than ~300 lines, more than one lab, or a project-wide convention. Stop, post a **change card** (what, why, cost, risk, rollback, picture if it helps), and wait for a yes. No answer means no.
- **Tier 3 · Never:** AWS keys in a session, `make bootstrap`, disabling a guardrail, force-pushing `main`, approving your own deployment.
- When unsure of the tier, treat it as Tier 2.

## Workflow
1. Branch from `main` as `<area>/<topic>`, for example `lab00/budgets` or `cc/naming`. Area is `lab00`…`lab11`, `labd`, `platform` or `cc` (control center). Don't use Linear's `gitBranchName`: an issue number says nothing. Never push to `main`.
2. Keep the change scoped to the issue. Anything else you notice becomes a new Linear issue with the `Idea` label.
   - Work only toward the issue's **Done when**. A new topic, tool, dependency, lab or goal is an `Idea` issue, not work, however small.
   - To grow a task past its issue, stop and ask Yaaf with a change card. No answer means no.
   - The same failure after two fix attempts: stop and report it. Don't keep trying.
   - Say what you skipped or deferred, and why, in the handoff and the PR.
3. Before finishing:
   - update the lab README (Proof, Cost receipt, Decisions, What broke) and its frontmatter `status`, and keep the root README lab table in sync
   - run `python3 tools/kb-check.py` and fix what it reports
   - hand off in a comment on the Linear issue: what changed, what's next, open questions, and the PR link. Then move the issue to the right state.
   - open a PR titled `<Area> · <plain name> (<issue ID>)`, for example `Lab 00 · Budget alerts (YAA-9)`. The ID at the end links the PR to Linear. Commit subjects start with the area: `lab00: add budget alerts`.
   - in handoffs and comments, name an issue by what it is first, then its ID: "budget alerts (YAA-9)"
4. Never mark a lab ✅ without a working proof. Record the first failed run in "What broke"; don't rerun until green and hide it.

## Cloud sessions
- The Cloud-Project environment runs `tools/cloud-setup.sh` (pinned, SHA256-checked tools). Bump a version and its hash together, then paste the file into the environment's setup script.
- Docker doesn't start on its own. Run `dockerd &` first.
- Open PRs with `gh api repos/yaaf-some/cloud-project/pulls`. `gh pr` uses GraphQL, which the proxy blocks.
- Never print or echo token variables.

## Knowledge-base rules (no wiki sprawl)
- Lab knowledge goes in the lab's README. `kb/` is only for what spans several labs, with at most 8 files and 250 lines each.
- Never create session, meeting or status notes in the repo. Those belong in Linear and the PR.
- Replace instead of appending. Delete anything stale; git history is the archive.
- Full rules: `kb/index.md`.

## Writing and presenting
Follow [`.claude/skills/runway-writing/SKILL.md`](.claude/skills/runway-writing/SKILL.md) for every doc, PR, Linear issue, comment and scheduled-task prompt. In short: result first, short sentences, numbers over adjectives, no em dashes in prose, a change card for every decision.
