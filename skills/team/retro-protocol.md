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

At the **very start of the skill** (before Step 0), clear this file to prevent state leaking from previous sessions:

```bash
> .claude/retro-session-agents.txt
```

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
> ## Recommendations for Next Time
> [specific, actionable — for role definitions, prompts, or the protocol]
> ```
>
> The session ID and participants map are in your context from Phase 1. Produce the retrospective immediately and directly.

---

## Prepending the Retrospective to the Deliberation Log

After Phase 3 returns the retrospective text, the lead prepends it to the deliberation log using this safe atomic pattern:

```bash
LOG_PATH="docs/trifecta-log-<timestamp>-<slug>.md"  # use the actual path
RETRO_CONTENT="<the Phase 3 output>"

if [ -f "$LOG_PATH" ] && [ -w "$LOG_PATH" ]; then
  { printf '%s\n\n---\n\n' "$RETRO_CONTENT"; cat "$LOG_PATH"; } > "${LOG_PATH}.tmp" \
    && mv "${LOG_PATH}.tmp" "$LOG_PATH" \
    && rm -f .claude/retro-transcripts.txt .claude/retro-session-agents.txt
else
  echo "WARNING: cannot prepend to $LOG_PATH (missing or not writable)"
fi
```

Key points:
- The `mv` pattern is atomic on same-filesystem operations (guaranteed here). Do not use `cat > original && rm temp` — that is NOT atomic and has a data-loss window.
- Cleanup of `retro-transcripts.txt` and `retro-session-agents.txt` only runs on success. If the prepend fails, artifacts are left in place for debugging.
- The resulting file has the retrospective at the top, then `---`, then the original deliberation log.

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
