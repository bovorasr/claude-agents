# Post-Implementation Review Protocol

This document is injected into the lead's context. It covers Step 7: the post-implementation review that runs after all implementation agents report done and before the retrospective.

---

## Purpose

Implementation agents often report "done" when the code compiles or tests pass — without honestly accounting for workarounds, technical debt, assumptions made under pressure, or gaps between what was planned and what was shipped. Step 7 forces that accounting and routes concerns to resolution before the session closes.

---

## Explain-Process Framework

The lead appends the following to every implementation agent's task, in the "before reporting done" section. Do not paraphrase — include this verbatim:

---

**Before reporting done, produce an honest implementation review as part of your completion report.** Use this format:

### Implementation Review

**What went wrong**: Every unexpected issue encountered — including ones you "fixed." Don't minimize.

**Workarounds & shortcuts**: Any flag, skip, temporary solution, or deviation from the plan. For each: why it was chosen and what it might cause later.

**Claims vs. reality**: If you said or implied "this is better" or "this is fine" at any point, verify those claims against actual evidence. Identify any rationalization.

**Technical debt introduced**: What shortcuts need future cleanup? What's now "permanent temporary"?

**Breaking changes or assumptions**: What existing behavior might be affected? What did you assume without verifying?

**Honest assessment**: One paragraph — is this implementation actually good, or just working?

If you have nothing to report for a section, say "None." Do not omit sections.

---

## Architect Review Format

When spawning the architect for Step 7 review, include all explain-process reports and the alignment document inline, plus these instructions verbatim:

---

You are reviewing the implementation of [slug]. Below are the alignment document and explain-process self-reports from every implementation agent.

Review for:
- Did implementation match the architectural approach in the alignment doc?
- Are the workarounds and shortcuts acceptable, or do they undermine the design?
- Is the technical debt introduced within acceptable bounds, or does it block the feature?
- Are there security, correctness, or integration issues that need immediate resolution?

Return your review in this format:

## Architect Review: [slug]
Severity: green | yellow | red

### Cleared
[What you're satisfied with — specific, not generic]

### Concerns
For each concern:
- **What**: [specific problem]
- **Where**: [agent / component / file if mentioned]
- **Why it matters**: [architectural or correctness implication]
- **Fix**: [what needs to change, specific enough to act on]
- **Fundamental?**: yes (requires trifecta re-deliberation) | no (implementation fix)

### Overall assessment
[One honest paragraph]

---

## Escalation Rules

| Situation | Action |
|---|---|
| Architect: green | Write review doc, proceed to retro |
| Architect: yellow/red | Lead orchestrates fix round per concern |
| After fix round: architect clears | Write review doc, proceed to retro |
| After fix round: architect still unsatisfied | Architect re-spawned with `permissionMode: default` and explicit implementation authorization to fix it themselves |
| Architect flags fundamental: yes | Lead reconvenes trifecta (Step 0 flow with scoped question); implementation waits |
| Re-spawned architect implements: complete | Architect reviews own work (auto-cleared), write review doc, proceed to retro |

One fix round maximum before escalation. The lead does not loop indefinitely.

---

## Review Document

The lead writes `docs/review-YYYYMMDD-HHMMSS-[slug].md` using the Write tool with the architect's review text (same slug as the alignment doc). This file is:
- Passed to the retro-coordinator in Phase 1 (if it exists)
- A permanent record of implementation quality for the session

---

## Category C Note

For Category C tasks (no trifecta, mechanical changes): Step 7 is **non-blocking for trifecta escalation**. Still collect explain-process reports and have the architect review. If the architect flags concerns, run a fix round. But if the architect flags a concern as "Fundamental: yes", log it in the review doc rather than reconvening a trifecta — there is no alignment doc to reconcile against.
