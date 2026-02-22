# Trifecta Deliberation Protocol

This document is in the lead's context during trifecta deliberation. It is NOT forwarded to trifecta sub-agents in Round 1 spawn payloads — doing so would expose cross-role tensions and bias initial positions before deliberation begins.

---

## Role Tensions

The trifecta works because these three roles have structurally different interests:

- **Architect** wants technical purity and long-term sustainability. Tends to identify the "right" abstraction, call out shortcuts that create debt, and see the big picture of system evolution. Risk: over-engineers, resists pragmatic cuts.
- **Product Owner** wants value delivered to users quickly. Measures everything in outcomes and timeline. Pushes to cut scope, challenges complexity that doesn't serve users directly. Risk: under-engineers, accumulates tech debt.
- **UX** wants the experience to be usable and the user's mental model to match the system. Resists technically elegant solutions that confuse people. Advocates for flows, edge cases from a user perspective. Risk: doesn't see implementation cost, can block progress over aesthetic concerns.

Disagreement between these roles is expected and healthy. The goal is alignment, not consensus.

---

## When to Convene the Trifecta

**Always (Category A — Feature / product decision):**
New features, user-facing behavior changes, significant scope decisions, anything the user described as "what to build" rather than "how to build it."
> Examples: "add user notifications," "redesign the checkout flow," "add OAuth login"

**Always (Category B — Technical change with user-facing or scope implications):**
Refactoring, migrations, or performance work where the technical change affects data availability, authentication, permissions, or any user-visible behavior.
> Examples: "refactor auth to support OAuth," "migrate REST to GraphQL," "improve search performance"

**Skip (Category C — Purely mechanical task):**
Implementation of a fully-specified change with no scope or user-facing decisions.
> Examples: "fix the null pointer in UserService," "rename method X to Y," "add a unit test for existing behavior"

---

## Deliberation Loop

### Round 1 — Initial Positions

Spawn architect, product-owner, and ux **in parallel**. Each agent's spawn payload contains ONLY:
- The user's request verbatim
- Their own role definition (system prompt text)
- The Round 1 format instructions below (format varies by category)

Do NOT include this document (`trifecta.md`) in Round 1 spawn payloads.

Each agent runs as an independent subprocess with its own isolated context window. Agents cannot see each other's responses unless the lead explicitly includes them.

**Category A — Round 1 format (adversarial):**

Include this in each agent's spawn payload:

> Produce your Round 1 trifecta position as structured text in your response. CRITICAL: Do NOT invoke the Write tool — your output must be plain text in this response only. Use this format (≤ 300 words total):
>
> **What I want** [bullet points]
> **What concerns me** [bullet points]
> **What I'll push back on** [bullet points]

**Category B — Round 1 format (conditional assessment):**

Include this in each agent's spawn payload:

> Evaluate whether this technical change has implications in your domain. CRITICAL: Return this as plain text in your response — do not invoke the Write tool. Use this format (≤ 200 words total):
>
> ```
> User-facing implications? Yes/No — [1–2 sentence reasoning]
> Scope implications? Yes/No — [1–2 sentence reasoning]
>
> [Include the following ONLY if you answered Yes above:]
> What I want: [bullet points]
> What concerns me: [bullet points]
> What I'll push back on: [bullet points]
> ```

**Lead processing for Category B responses:**
- **All three: No to both** → produce a minimal alignment doc (≤ 200 words) confirming containment; skip to implementation
- **Any agent: Yes to either** → treat existing responses (which already contain pushback) as Round 1 positions; proceed directly to Round 2. Do not re-run Round 1.

### Round 2 — Cross-Examination

Synthesize only the specific points where positions conflict. Use this format (≤ 150 words per topic):

```
CONFLICT BRIEF

[Topic 1]:
  Architect: [1 sentence]
  PO: [1 sentence]
  UX: [1 sentence]
  Question for each role: [what they need to respond to]

[Topic 2]: ...
```

Each role receives this brief and responds to the other roles' concerns (≤ 200 words per agent).

### Round 3 — Resolution (if needed)

If significant disagreements remain after Round 2, run one more targeted round focused only on unresolved blocking objections (≤ 150 words per agent).

After Round 3, remaining tensions are logged as tracked risks — they do not block. If any role still has a *blocking* objection after Round 3, escalate to the human (see Escalation section below).

---

## Deliberation Log

Before writing the alignment document, write a **deliberation log** to the same directory. This is the raw record of what each agent actually said — preserved verbatim for debugging and iteration.

> **Note:** At the end of the session (Step 8), the lead prepends a **Trifecta Retrospective** to this file. The retrospective is written above the log content, separated by `---`. The original log is unchanged.

**Filename:** `docs/trifecta-log-YYYYMMDD-HHMMSS-[slug].md` (same timestamp and slug as the alignment doc).

**Format:**

```
TRIFECTA DELIBERATION LOG
Feature: <slug>
Date: YYYY-MM-DD HH:MM:SS
Category: A / B / C

Agent transcripts (subagents/ directory of this session):
  Architect:     agent-<id returned by Task tool>.jsonl
  Product Owner: agent-<id returned by Task tool>.jsonl
  UX:            agent-<id returned by Task tool>.jsonl

---

## Request

<the user's request verbatim>

---

## Round 1 — Initial Positions

### Architect
<paste response verbatim>

### Product Owner
<paste response verbatim>

### UX
<paste response verbatim>

---

## Conflict Brief (sent to Round 2)

<paste the CONFLICT BRIEF verbatim, or "N/A — all agents agreed / Category B all-No">

---

## Round 2 — Cross-Examination
(omit section if Round 2 was not run)

### Architect
<paste response verbatim>

### Product Owner
<paste response verbatim>

### UX
<paste response verbatim>

---

## Round 3 — Resolution
(omit section if Round 3 was not run)

### Architect
<paste response verbatim>

### Product Owner
<paste response verbatim>

### UX
<paste response verbatim>

---

## Lead Synthesis Notes

<1–3 sentences: what the lead observed about the deliberation — where the real tensions were, what drove the alignment decisions, anything notable about agent behavior>
```

The deliberation log has no size limit. It is not injected into implementation agents — it is for human inspection only. Write it before writing the alignment document.

---

## Alignment Output

### File path convention

Write both the deliberation log and the alignment document to:
- `docs/` if it exists
- `architecture/` if that exists and `docs/` does not
- Create `docs/` and write there if neither exists

Both files share the same timestamp and slug: `YYYYMMDD-HHMMSS-[slug]`. The slug is a 3–5 word lowercase hyphenated summary of the feature (e.g., `user-notifications`, `oauth-login`).

### Size constraint

The alignment document must be **≤ 600 words**. This is a hard limit — the document is included verbatim in every implementation agent's spawn payload. If the deliberation output would exceed this, summarize rather than transcribe. The deliberation log has no such constraint.

### Content template

```
ALIGNMENT DOCUMENT
File: docs/alignment-YYYYMMDD-HHMMSS-[slug].md

Feature: <what we're building>
User need: <PO's framing — what problem does this solve for the user>
Scope: <what's in, what's explicitly out>

Architecture approach: <architect's recommended approach, accepted by the group>
Key constraints: <technical constraints UX and PO accepted>

UX decisions: <key interaction/flow decisions, accepted by the group>
UX risks: <known UX risks that implementation must account for>

Deferred items: <things PO cut that UX or architect wanted — tracked for future>
Remaining tensions: <disagreements that are logged but not blocking>

Open questions: <things that will be resolved during implementation, not before>
```

---

## Alignment Definition

Alignment is reached when:
- Each role's primary concern is addressed (accommodated, traded off with explicit reasoning, or logged as deferred)
- No role has a *blocking* objection — they may prefer differently, but can live with the decision
- The lead has a document that developers can implement without needing to re-litigate scope or approach

Alignment is NOT full agreement, the architect's technical ideal, the PO's minimum viable scope, or the UX's perfect flow.

---

## Escalation to Human

If after Round 3 any role still has a blocking objection, surface it to the human with:
- Which role is blocking and why
- The specific unresolved point
- The options available
- A clear decision question

The trifecta does not make unilateral calls that any member considers blocking. Wait for the human's decision before proceeding to implementation.

---

## Agent Failure Recovery

If a Round 1 trifecta agent returns a malformed response, errors, or times out:

1. Retry that agent once with the same payload
2. **1 failure after retry:** proceed with the two available positions; note the gap in the alignment document ("Note: [role] position unavailable — implementation should flag any [role] concerns during plan approval"); inform the user before proceeding
3. **2+ failures after retries:** abort the trifecta entirely. Do not proceed with a partial deliberation. Escalate to the user with: which agents failed, what was attempted, and whether to retry the full trifecta or proceed without it.
4. Do not proceed to implementation when 2+ agents have failed. A trifecta with only one perspective is not a trifecta.
