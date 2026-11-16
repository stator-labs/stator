---
name: runway-presenting
description: How to report work to Yaaf and ask him for a decision in Runway. Use for handoffs, PR descriptions, Linear comments, session summaries, and every Tier 2 change card (AWS, cost, trust, deletion, public, scope).
---

<!--
Merges the human-in-the-loop draft's change card (approved 2026-11-16) with the
presentation standard from YAA-24. Ideas, not text, from
tamdogood/builder-essential-skills@1be9984bdafbb68eaff400bdd82773a1d41ee7ec (MIT):
"checked / not checked" from map-the-landscape, the skipped list from lead.
When to ask (the tiers) is in AGENTS.md. Why: kb/human-in-the-loop.md.
-->

# Runway presenting

Yaaf reads on a phone, between other things. He should be able to judge any request in a minute. If he can't, the request is the problem.

## Every report
1. **Result first.** The first line says what happened or what you need: "PR #12 is ready; it needs one decision."
2. **Tables** to compare two or more options, files or states. Prose for one line of reasoning.
3. **A Mermaid diagram** when trust, data flow or structure changes (a new role, an OIDC trust, a pipeline step). GitHub renders it. Skip it when a table says the same.
4. **Checked / not checked.** Say what you ran or read at the source, and what you inferred or could not test.
5. **Skipped.** What you left out or deferred, and why. Write "nothing" when it's nothing.

A **handoff** (Linear comment at the end of a session) is those five points plus what's next, open questions and the PR link.

## Change card
One card per decision, not per step. It fits on one screen. Show what will happen, then ask.

```markdown
### <What> · Tier 2: <trigger>
**Why:** one sentence; link the issue.
**What changes:** table of file or resource · add / change / destroy · note.
**Picture:** Mermaid, when trust, data flow or architecture changes.
**Cost:** one-time · monthly · idle, with the source (Infracost or the AWS pricing page). "$0" needs a reason.
**Risk:** what breaks if this is wrong, and who notices.
**Security:** permissions or trust added or widened. "None" is a valid answer.
**Rollback:** exact steps, and whether it is fully reversible.
**Checked / not checked:** what you verified, and what only real AWS or a real run will show.
**Decision:** approve · change · decline. Recommended: <one>, because <reason>. No answer means nothing happens.
```

Where the card goes:
- **AWS change:** the PR (plan comment and description), then the `aws-apply` approval in GitHub.
- **Repo-wide change:** the PR description. The PR template has the same fields.
- **Anything else:** your message in the session, and a comment on the Linear issue.

## Interruptions
- **Push notification:** only for a Tier 2 card, or a failure that blocks the work.
- **Everything else** goes in the handoff, the PR and the weekly board-health update.
- **Bundle:** one message holds every open decision, each with a recommendation.
- **Ask once:** a decision already recorded in Linear stands. Don't ask it again.
- **Stale:** board health re-raises an unanswered card once, then drops it.
