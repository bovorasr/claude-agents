# Retrospective Protocol

This document is injected into the lead's context. It covers the full three-phase retrospective that runs after all implementation work is complete — the last step before the lead reports done to the user.

---

## Session ID

`${CLAUDE_SESSION_ID}` is the literal UUID of this session, substituted into the lead's context when the skill was invoked. The lead sees it as a concrete value (e.g., `d9e43862-b73c-4075-b250-9a6006816f4d`). Pass this value directly as the argument to `retro-extractor.sh` — no shell variable persistence is needed; the lead hard-codes the UUID it already has in context.

---

## Agent ID Tracking (Throughout the Session)

After **every** Task call completes — trifecta agents, implementation agents, all of them — append a line to `.claude/retro-session-agents.txt`:

```
<role>: <agentId>
```

Exact format, no extra spaces. Example:

```
architect: a77e4249dd7dd9b9e
product-owner: b33f1234abc
senior-dev: c99e5678def
```

The agentId is returned by the Task tool in the tool result. This file is written incrementally — do not rely on in-context memory alone over a long session.

At the **very start of the skill** (before Step 0), use the Write tool to create `.claude/retro-session-agents.txt` with empty content. This clears any state from previous sessions. To append each entry: use the Read tool to get the current contents, add the new `role: agentId` line, and use the Write tool to save it back.

---

## Phase 1 — Lead Prepares + Retro-Coordinator Analyzes

**Lead runs (one command):**

```bash
bash .claude/skills/team/retro-extractor.sh "${CLAUDE_SESSION_ID}" > .claude/retro-transcripts.txt
```

Where `${CLAUDE_SESSION_ID}` is the literal UUID already in the lead's context — pass it directly as the argument string.

**Lead then reads** `.claude/retro-transcripts.txt` and **spawns retro-coordinator** with all content inline (no file paths):

- The deliberation log content (verbatim, pasted inline)
- Contents of `.claude/retro-transcripts.txt` (pre-extracted transcripts for all participants, labeled by role)
- The complete `{role: agentId}` map (read from `.claude/retro-session-agents.txt`)
- The contents of `docs/review-YYYYMMDD-HHMMSS-[slug].md` (if it exists), under a `## Implementation Review` heading
- These Phase 1 instructions:

> You are facilitating Phase 1 of a team retrospective. Review the deliberation log and transcript excerpts provided. Return:
>
> 1. **Preliminary observations** (≤ 300 words): Did each agent argue from their role's genuine perspective? Did the protocol produce the intended dynamics? Where did the session go well or break down? Include specific examples.
>
> 2. **Per-participant questions** (3–5 questions each, with 1–2 sentence transcript quotes as context). Format each participant section as:
>
> ### [Role]
> **Q1:** [question]
> > [1–2 sentence quote from their transcript]
>
> 3. **If an implementation review document is provided:** Note what went wrong during implementation, and assess what the planning phase (trifecta or alignment doc) should have caught but didn't. Were there architectural decisions that made implementation harder than necessary?
>
> All content you need is provided inline. Produce your analysis immediately and directly.

**Retro-coordinator returns to lead (text only, no file writes):**
- Preliminary observations
- Per-participant questions with transcript quotes

---

## Phase 2 — Self-Assessments

Lead spawns **all session participants in parallel** — everyone recorded in `.claude/retro-session-agents.txt` (architect, product-owner, ux, plus any implementation agents).

Each spawn payload includes (all inline — not file paths):
- Their own pre-extracted readable transcript (their labeled section from `.claude/retro-transcripts.txt`)
- Their role definition (system prompt text)
- The retro-coordinator's questions for them specifically
- This instruction:

> Your transcript from this session is below. Reflect honestly on your participation. Did you argue from your role's genuine perspective? Where did you drift? What would you do differently? Answer the questions below. ≤ 300 words total.

Each agent returns their self-assessment as text. No file access needed — everything is inline.

---

## Phase 3 — Synthesis

Lead spawns **retro-coordinator** again with:
- The Phase 1 preliminary observations verbatim (already ≤ 300 words — do not re-paste extended transcript content)
- All self-assessment responses, labeled by role
- These Phase 3 instructions:

> You are facilitating Phase 3 synthesis of a team retrospective. Using the preliminary observations and self-assessments provided, write the final retrospective (≤ 800 words). Use this exact format:
>
> ```
> # Trifecta Retrospective
> Feature: <slug>
> Date: YYYY-MM-DD
> Session: <session-id>
> Participants: <role: agentId, ...>
>
> ## What Went Well
> [specific behaviors — not generalities]
>
> ## What Didn't Work
> [specific failures with examples from the transcripts]
>
> ## Agent Self-Assessments
> ### Architect
> [self-assessment]
> ### Product Owner
> [self-assessment]
> ### UX
> [self-assessment]
> ### [implementation agents]
> [self-assessments]
>
> ## Retro Coordinator's Observations
> [what the transcripts revealed beyond what the log shows]
>
> ## Implementation Quality
> [What the explain-process reviews revealed — specific findings, not summaries.
> What the trifecta or alignment doc should have anticipated but didn't.
> Recommendations for planning better to avoid these issues next time.
> Omit this section if no implementation review document was provided.]
>
> ## Recommendations for Next Time
> [specific, actionable — for role definitions, prompts, or the protocol]
> ```
>
> The session ID and participants map are in your context from Phase 1. Produce the retrospective immediately and directly.

---

## Prepending the Retrospective to the Deliberation Log

After Phase 3 returns the retrospective text:

1. Use the **Read tool** to get the current contents of the deliberation log (`docs/trifecta-log-<timestamp>-<slug>.md`).
2. Construct the combined content: the Phase 3 retrospective text, then `\n\n---\n\n`, then the original log content.
3. Use the **Write tool** to save the combined content back to the log file.
4. Run cleanup with the Bash tool:

```bash
rm -f .claude/retro-transcripts.txt .claude/retro-session-agents.txt
```

If the Write fails, skip cleanup and note the failure — temp files left in `.claude/` can be used for debugging.

The resulting file structure:

```
# Trifecta Retrospective
[≤ 800 words]

---

# Trifecta Deliberation Log
[original log, unchanged]
```

Final file structure:

```
# Trifecta Retrospective
[≤ 800 words]

---

# Trifecta Deliberation Log
[original log, unchanged]
```

---

## Failure Handling

If any phase fails (retro-coordinator errors, extraction produces empty output, log file missing or not writable):

- Log the failure: write a brief note at the top of the deliberation log if possible — `# Trifecta Retrospective\n\n[RETRO FAILED: <reason>]\n\n---\n\n`
- Proceed to the final user report — the retrospective is non-blocking. Implementation is already complete.
- One retry per phase is acceptable. Do not retry indefinitely.
