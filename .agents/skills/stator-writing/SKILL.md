---
name: stator-writing
description: Plain English writing rules for Stator (Orwell's six rules + ASD-STE100). Applies to every doc, ticket, PR, code comment, skill and chat reply.
---

<!--
Adapted from tamdogood/builder-essential-skills, skills/orwell-writing/SKILL.md
https://github.com/tamdogood/builder-essential-skills/tree/main/skills/orwell-writing
MIT License, Copyright (c) 2026 Tam Nguyen. See LICENSE in this folder.
-->

# Stator writing

Write like a sharp human teammate, not a corporate form. Cut half your first draft.

## Orwell's six rules
1. Never use a worn-out metaphor, simile or figure of speech.
2. Never use a long word where a short one will do.
3. If you can cut a word, cut it.
4. Never use the passive where you can use the active.
5. Never use jargon or a foreign phrase when a plain word works.
6. Break any of these rules sooner than sound robotic or awkward.

## Plain English baseline
- **Short replies by default.** Say what happened and what's next. Stop.
- **One point per sentence.** Name the actor: "CI runs the plan", not "the plan is run".
- **Numbers beat adjectives:** "$0.42/run", not "cheap".
- **Keep exact technical terms** (`stator-apply`, OIDC, `default_tags`, code, commands, IDs).
- **Procedures:** condition, action, expected result.
- **No em dashes in prose.** Use a period, colon, comma or parentheses.
- **No AI filler:** cut buzzwords and padding like:
```text
seamless, robust, leverage, pivotal, "in order to" -> "to",
"due to the fact that" -> "because", "it is important to note",
"Great question", "I hope this helps"
```
- **Skip empty fields.** If cost is $0 or security impact is none, don't write a paragraph about it.

`python3 tools/docs-lint.py` enforces the style checks in CI.

## Formats
- **Linear issue:** 1–2 lines of why, then **Done when** bullets. Put logs or file lists in a collapsible `+++ Agent notes` block.
- **Issue refs in prose:** describe it first, then the ID: "budget alerts (STAT-9)".
- **Lab README:** follow `templates/lab-README.md`. Proof first. "Why not X?" in 2–3 sentences. Keep the first failure in "What broke".
- **Headings:** sentence case. Titles use `·`: `Lab 05 · AI Agent Sandboxing`.
