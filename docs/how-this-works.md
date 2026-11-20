---
title: How this project runs
updated: 2026-11-14
---

# How this project runs

## Where things live
| What | Where | Lifetime |
|---|---|---|
| Lab knowledge (decisions, proof, cost, what broke) | `labs/NN-*/README.md` | as long as the lab exists |
| Cross-lab knowledge | `docs/`, at most 8 files (see [index](index.md)) | replaced, never appended |
| Work items, the board, handoffs between sessions | Linear: workspace `yaaf-some`, team Stator (key `STAT`) | closes with the issue |
| Discussion of a change | the PR description and review | closes with the PR |
| Briefing for Claude sessions | claude.ai Project "Cloud-project" → `claude/runway-control-center.md` | kept current |

## Reading it on any device
- **Phone or tablet:** the GitHub mobile app or github.com. Markdown and Mermaid diagrams render there, and it's free.
- **Mac:** open the repo folder as an Obsidian vault for links and graph view, or use any editor. Git does the syncing: `git pull`.
- **iPhone with Obsidian (optional):** a free git client such as ObSync pulls the repo into an Obsidian vault. Not required.
- **Public site (optional, later):** the same markdown can be published free with Quartz on GitHub Pages. Tracked as a Linear `Idea`.

## The board (Linear)
| Column | Linear state |
|---|---|
| **Now** (max 2) | In Progress |
| **Next** | Todo |
| **Later** | Backlog |
| **Ideas** | Backlog + `Idea` label |

- The `Role` label group (SA, Platform, Cloud, SRE, Security, AI Infra, Defense) shows what each issue showcases.
- The `Process` label marks meta work.
- New trends never trigger a plan rewrite. They become `Idea` issues and, if worth watching, a row in [radar](radar.md).

## Sessions
- **Control center:** a long-running Claude session that plans, dispatches and reviews. It stores nothing itself: the plan lives in Linear, the work in the repo.
- **Cloud workers:** background Claude agents. One Linear issue each, its branch, a PR. Rules: [Tier 3](../AGENTS.md#human-in-the-loop).
- **Local sessions:** Claude Code on Yaaf's Mac. Same rules as cloud workers. Start one with "work on <issue title> (RUN-NN)".
- **Handoff:** every session ends with a comment on its Linear issue (what changed, what's next, open questions) and the PR link.
- **Scheduled tasks:**
  - weekly **trend radar**: updates [radar](radar.md) and adds `Idea` issues
  - weekly **board health**: Linear hygiene and `tools/docs-lint.py`
  - one-off **re:Invent 2026 digest**: Dec 5

## Real AWS without surprise bills
- Budgets at $5 / $15 / $30, and Cost Anomaly Detection.
- Tags on everything: `project=runway`, `lab=<nn>`, `runway:ephemeral`.
- `make up` / `make down` per lab. A nightly reaper lists ephemeral resources; it starts as a dry run, and each ephemeral lab adds the delete rights for its own services. `make nuke` for everything comes with the first ephemeral stack.
- Agents write OpenTofu; GitHub Actions applies it. A PR gets `tofu plan` (read-only OIDC role); a merge to `main` runs `tofu apply` after Yaaf approves the `aws-apply` environment. See [platform/infra](../platform/infra/README.md).
- Yaaf's terminal is only for `make bootstrap`: the state bucket and the two OIDC roles. Run once, and again when the bootstrap stack changes. It also stores the alert email as the Actions secret `ALERT_EMAIL`: the repo is public, so the address is never committed.

## Writing a lab
Copy `templates/lab-README.md`. Lead with the proof. Every lab has a cost receipt. Decisions go inline as "Why not X?" paragraphs.
