---
name: stator-presenting
description: How to report work and ask Yaaf for decisions. Short, human, exception-based: skip boilerplate and empty fields.
---

# Stator presenting

Yaaf reads on a phone. He should grasp any update or ask in 15 seconds.

## Rules
1. **Result first.** One line: what changed or what you need.
2. **Skip empty fields.** Don't repeat "Cost: $0", "Security: None", or "Skipped: Nothing". State only what actually changes, breaks or costs money.
3. **Tables for comparisons, bullets for steps.** Add a Mermaid diagram only when trust boundaries or data flow change.
4. **Honest verification.** One line on what ran vs what still needs real AWS or CI.
5. **No form spam.** Don't paste identical 10-field cards for routine work.

## Asking for a Tier 2 decision
Only for real risk (AWS apply/destroy, cost > $0, IAM/OIDC/trust, deletion, repo-wide rule changes). Keep it tight:

```markdown
**Ask (Tier 2: <trigger>):** <what you want to do, in one line>
- **Change:** <files or resources added/changed/destroyed>
- **Risk / cost:** <only what's non-zero; what breaks if wrong>
- **Rollback:** <how to undo>
- **Call:** <approve / pick A or B> (recommend <X>, because <short reason>)
```

## Handoffs (Linear comments)
4–6 lines: what landed (PR/commit link), what ran, what's next, and any open call.
