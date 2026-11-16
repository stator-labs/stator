---
name: runway-writing
description: How to write and present anything in Runway. Use for every README, kb page, PR description, Linear issue or comment, handoff, scheduled-task prompt and change card. Plain English (Orwell's rules, a short ASD-STE100 baseline), results first, tables and Mermaid where they help.
---

<!--
Adapted from tamdogood/builder-essential-skills, skills/orwell-writing/SKILL.md
https://github.com/tamdogood/builder-essential-skills/tree/1be9984bdafbb68eaff400bdd82773a1d41ee7ec
MIT License, Copyright (c) 2026 Tam Nguyen. Full notice: LICENSE in this folder.
Changes: cut the creative-writing section and the workflow steps; kept the six rules
and a shorter STE list; added the AI-tells list from skills/write-blog/reference/voice.md;
added Runway's presentation standard, change card, Linear and lab README formats.
This file replaces the "Writing style" section of AGENTS.md.
-->

# Runway writing

Readers: Yaaf on a phone, a hiring manager on GitHub, the next agent. Write so each one gets the point in the first two lines.

## Rules
Orwell's six, from "Politics and the English Language":
1. Never use a metaphor, simile or figure of speech you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If you can cut a word, cut it.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word or jargon if an everyday word exists.
6. Break any of these rules sooner than say anything barbarous.

Runway additions (a short ASD-STE100 baseline):
- One statement per sentence. Short sentences.
- Name the actor: "GitHub Actions applies the plan", not "the plan is applied".
- One term for one thing. Don't switch between "stack", "module" and "workspace" for variety.
- Numbers beat adjectives: "$0.42 per run", not "cheap".
- Keep exact technical terms (`runway-apply`, OIDC, `default_tags`, "blast radius"). Plain English must not lose precision. Code, commands, IDs and product names stay as they are.
- Instructions: condition, action, expected result.
- No em dashes (—) in prose. Use a period, colon, comma or parentheses. A lone "—" in a table cell means "no value". En dashes (–) are for number ranges only.

Cut these AI tells:
- Inflation: "pivotal", "testament to", "plays a key role", "in today's landscape".
- Sales words: "seamless", "robust", "powerful", "cutting-edge", "game-changing".
- "It's not just X, it's Y." Triples of adjectives. Sentences ending in "..., highlighting the need for ...".
- Filler: "in order to" → "to"; "due to the fact that" → "because"; "it is important to note that" → say it.
- Chat residue: "Great question", "I hope this helps", "Let me know if".
- Bold on every noun. Bold a term once, where you define it.

`python3 tools/kb-check.py` flags the stock phrases (it fails) and em dashes (a warning for now).

## Presenting work to Yaaf
1. **Result first.** The first line says what happened or what you need: "PR #12 is ready; it needs one decision."
2. **Tables for comparisons** of two or more options, files or states. Prose for one line of reasoning.
3. **A Mermaid diagram** when structure, data flow or trust changes (a new role, an OIDC trust, a new pipeline step). GitHub renders it. Skip it for anything a table shows.
4. **Checked / not checked.** Mark each claim you tested or read at the source. Mark what you inferred or could not verify.
5. **Skipped.** List what you left out and why, even when it's nothing.
6. **A change card** when Yaaf must decide (see below). Never bury a decision in prose.

## Change card
Use it for every decision that needs Yaaf's yes. The human-in-the-loop policy says when. This is the format.

```markdown
**Change card: <what, in a few words>**
| | |
|---|---|
| What | the change, in one or two sentences |
| Why | the problem it solves; link the issue |
| Cost | dollars per month, or $0; one-time cost |
| Risk | what could go wrong, and how likely |
| Rollback | the exact steps or command |
| Checked | what you tested or read |
| Not checked | what you could not test |

**Decision:** <the question>. Recommendation: <yes/no/option>, because <one reason>.
No answer means no.
```

## Formats
- **Linear issue:** human-readable first: one or two sentences of why, then **Done when** as a bullet list. Agent detail (file lists, plans, logs) goes last, in a collapsible block that opens with `+++ Agent notes` and closes with `+++`.
- **Handoff comment:** what changed, what's next, open questions, what you skipped, the PR link. Name an issue by what it is, then its ID: "budget alerts (YAA-9)".
- **Lab README:** the template order. Proof first. "Why not X?" paragraphs of 2–4 sentences. "What broke" keeps the first failure as it happened.
- **Headings:** sentence case. Titles use "·" as a separator: "Lab 05 · Agent Jail".
