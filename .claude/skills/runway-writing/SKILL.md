---
name: runway-writing
description: How to write anything in Runway. Use for every README, docs page, PR description, Linear issue or comment, and scheduled-task prompt. Plain English from Orwell's six rules and a short ASD-STE100 baseline; Runway's issue, README and heading formats. For reports and decisions, also use runway-presenting.
---

<!--
Adapted from tamdogood/builder-essential-skills, skills/orwell-writing/SKILL.md
https://github.com/tamdogood/builder-essential-skills/tree/1be9984bdafbb68eaff400bdd82773a1d41ee7ec
MIT License, Copyright (c) 2026 Tam Nguyen. Full notice: LICENSE in this folder.
Changes: cut the creative-writing section and the workflow steps; kept the six rules
and a shorter STE list; added the AI-tells list from skills/write-blog/reference/voice.md;
added Runway's Linear issue and lab README formats. Reports and change cards: runway-presenting.
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

`python3 tools/docs-lint.py` flags the stock phrases (it fails) and em dashes (a warning for now).

## Formats
- **Linear issue:** human-readable first: one or two sentences of why, then **Done when** as a bullet list. Agent detail (file lists, plans, logs) goes last, in a collapsible block that opens with `+++ Agent notes` and closes with `+++`.
- **Naming an issue** in prose: what it is, then its ID: "budget alerts (YAA-9)". Never a bare ID. All other names: AGENTS.md, Naming.
- **Lab README:** the template order. Proof first. "Why not X?" paragraphs of 2–4 sentences. "What broke" keeps the first failure as it happened.
- **Headings:** sentence case. Titles use "·" as a separator: "Lab 05 · AI Agent Sandboxing".
