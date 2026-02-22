# claude-agents

Reusable Claude Code agent definitions and skills for orchestrating teams of agents with worktree isolation, role-based delegation, and merge conflict escalation.

## Quick Install

From inside a project directory:

```bash
curl -fsSL https://raw.githubusercontent.com/bovorasr/claude-agents/main/install.sh | bash
```

If the current directory already has a `.claude/` folder, the installer uses it — no questions asked. If not, it asks whether to create `.claude/` here or install into `~/.claude/` (your global Claude config) instead. Either way, it then asks whether to enable the required feature flag in the same `settings.json`. In a non-interactive environment with no `.claude/` present, it exits with an error rather than guessing.

This installs the following into `.claude/`:

| File | Description |
|------|-------------|
| `.claude/agents/architect.md` | Systems thinker — design docs, interfaces, trade-off analyses. Never writes implementation code. |
| `.claude/agents/product-owner.md` | Delivery advocate — prioritizes user value, challenges scope, pushes for the minimum useful slice. Never writes code. |
| `.claude/agents/retro-coordinator.md` | Retrospective facilitator — analyzes session transcripts, synthesizes observations, produces actionable feedback. Only invoked at session end. |
| `.claude/agents/ux.md` | User experience advocate — flows, mental models, edge cases from a user perspective. Never writes code. |
| `.claude/agents/senior-dev.md` | Completes tested changes. Reads existing code first, matches style, runs tests before done. |
| `.claude/agents/junior-dev.md` | Precise task executor. Good at repetitive/scoped work. Flags ambiguity instead of improvising. |
| `.claude/agents/merge-specialist.md` | Classifies and resolves merge conflicts. Escalates contradictory conflicts with structured reports. |
| `.claude/skills/team/SKILL.md` | The `/team` slash command — orchestrates the other agents. |
| `.claude/skills/team/retro-protocol.md` | Retrospective protocol — three-phase retro flow, transcript extraction, prepend pattern. |
| `.claude/skills/team/retro-extractor.sh` | Shell script that extracts readable text from agent JSONL transcripts for retrospective input. |
| `.claude/skills/team/worktree.md` | Worktree coordination protocol — MERGE_CONFLICT format, escalation rules, lead responsibilities. |
| `.claude/skills/team/trifecta.md` | Trifecta deliberation protocol — deliberation loop, conflict templates, alignment doc format. |

## Design

Two ideas drive the structure of this repo.

**One definition, two uses.** The files in `agents/` are standard Claude Code subagent definitions — Claude Code picks them up natively from `.claude/agents/` and makes them available as `@architect`, `@senior-dev`, etc. The `/team` skill uses those exact same files when it spawns team members. There's no separate "team version" of each role; the same markdown that defines the standalone subagent is what gets injected into the orchestrated team. You get both capabilities from a single set of definitions.

**Role definitions are context-agnostic. Coordination logic is separate.** Each agent file describes *who the agent is* — its character, professional concerns, model, tools, and what it will and won't do. It says nothing about the `/team` command, trifecta rounds, or MERGE_CONFLICT messages.

What's team-specific lives in the protocol documents under `skills/team/`:
- `trifecta.md` — how the planning deliberation runs: round formats, conflict templates, the alignment doc structure
- `worktree.md` — how parallel implementation agents coordinate: the MERGE_CONFLICT message format, escalation rules

The lead injects these protocol docs into agents' spawn payloads at the right moment. An architect working in a trifecta gets the Round 1 format instructions added to its context; an architect invoked standalone gets none of that. Same agent definition, different context, appropriate behavior in both cases.

This separation means you can freely customize an agent's character (how it reasons, what it prioritizes, how assertive it is) without touching the coordination machinery — and you can evolve the coordination protocol without touching the agent definitions.

## Prerequisites

Agent teams are currently experimental and require a feature flag. The installer will prompt you to add it — but if you need to set it manually:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Add this to `.claude/settings.json` in your project, `~/.claude/settings.json` for all projects, or export `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your shell.

## Usage

Once installed, use the `/team` slash command in Claude Code:

```
/team add user authentication with JWT tokens and a refresh token flow
```

The lead orchestrator will:
1. Classify the request and run the trifecta if needed (Step 0)
2. Write a plan (roles, work breakdown, integration points)
3. Ask for your approval before spawning any agents
4. Spawn teammates with worktree isolation so they work in parallel without stepping on each other
5. Handle merge conflicts via the merge-specialist if parallel changes collide
6. Run a retrospective after all work is complete (Step 8)
7. Report back when complete

## Trifecta

For new features and product decisions, the lead convenes a **trifecta deliberation** before any implementation begins. Three planning agents — architect, product-owner, and UX — deliberate on what to build, then produce an alignment document that developers work from.

### When it runs

| Category | Example | Action |
|----------|---------|--------|
| A — Feature / product decision | "add user notifications" | Full trifecta |
| B — Technical change with user-facing implications | "refactor auth to support OAuth" | Full trifecta with scoped question |
| C — Purely mechanical task | "fix the null pointer in UserService" | Skip — go straight to implementation |

### What it produces

An **alignment document** written to `docs/alignment-YYYYMMDD-HHMMSS-[slug].md`. It covers:
- Feature description and user need
- Scope (in and explicitly out)
- Agreed architecture approach and key constraints
- UX decisions and UX risks
- Deferred items and remaining (non-blocking) tensions
- Open questions to resolve during implementation

The lead presents the alignment document to you and asks for approval before spawning any implementation agents. You can revise it — your changes are incorporated directly and implementation proceeds from the revised document.

### What alignment means

Alignment is reached when each role's primary concern is addressed — accommodated, traded off with explicit reasoning, or logged as deferred — and no role has a blocking objection. It is not full agreement, not the architect's technical ideal, not the PO's minimum viable scope, and not the UX's perfect flow.

## Retrospective

After all implementation work is complete, the lead automatically runs a **three-phase retrospective** before reporting done — like a real sprint retro, not mid-process.

### What it produces

A retrospective prepended to the top of the deliberation log (`docs/trifecta-log-*.md`), with the original log preserved below a `---` separator. The retrospective covers:

- What went well (specific behaviors, not generalities)
- What didn't work (specific failures with transcript examples)
- Agent self-assessments (each participant reflects on their own participation)
- Retro coordinator's observations (what the transcripts revealed beyond the log)
- Recommendations for next time (actionable — for role definitions, prompts, or the protocol)

### How it works

Three sequential phases run after implementation, orchestrated by the lead:

1. **Phase 1:** The lead extracts readable text from all agent transcripts (`retro-extractor.sh`), then spawns the retro-coordinator with the deliberation log + transcript excerpts inline. The coordinator returns preliminary observations and targeted questions per participant.

2. **Phase 2:** The lead spawns all session participants in parallel. Each receives their own pre-extracted transcript text, their role definition, and the coordinator's questions — inline, not as file paths. Each returns a self-assessment (≤ 300 words).

3. **Phase 3:** The lead spawns the retro-coordinator again with the Phase 1 observations and all self-assessments. The coordinator returns the final retrospective (≤ 800 words), which the lead atomically prepends to the deliberation log.

The retrospective is **non-blocking** — if any phase fails, the failure is noted and the session concludes normally.

### Why it matters

Run a trial, read the retro, improve role definitions and protocols, repeat. The retrospective is the feedback loop for iterating on the team itself.

---

## Updating

Re-run the same install command. The installer tracks a manifest at `.claude/.agent-team-manifest` to detect what's changed:

- **You haven't modified a file, upstream has** → auto-updated
- **You've modified a file, upstream unchanged** → your version kept
- **Both sides changed** → interactive conflict prompt with `[o]verwrite / [s]kip / [d]iff / [b]ackup`

In a CI or non-interactive environment, conflicts default to keeping your local version.

## Customizing and Creating Agents

These agents are a starting point, not a fixed roster. Modify the ones that ship here, add your own, or both.

**Modifying existing agents.** The files in `.claude/agents/` are plain markdown. Edit them directly — tighten a system prompt, swap the model, adjust the tool list, change the permission mode. The manifest records your local hash so upstream updates won't silently overwrite your customizations.

**Adding new agents.** Create a new `.claude/agents/your-role.md` file with the standard frontmatter:

```markdown
---
model: claude-sonnet-4-6
permissionMode: plan
tools:
  - Read
  - Write
  - Grep
---

Your system prompt here.
```

Claude Code will automatically pick it up as a standalone subagent (`@your-role`). The `/team` skill loads all files matching `.claude/agents/*.md`, so your new agent is available to the orchestrator immediately — no other configuration needed.

**What belongs in an agent definition — and what doesn't.**

Agent files are shared. The same file is used when you invoke `@architect` directly and when `/team` spawns an architect inside the trifecta. This is intentional, and it means agent definitions should stay context-agnostic.

Put in the agent file:
- The role's professional character and point of view
- What it produces and what it refuses to do
- Model, permission mode, and tool access

Keep out of the agent file:
- References to `/team`, the trifecta, or worktree coordination
- Instructions about what format to use in Round 1 vs Round 2
- Any behavior that only makes sense inside the orchestrated team workflow

That coordination logic lives in `skills/team/trifecta.md` and `skills/team/worktree.md`. The lead injects the relevant parts into an agent's context at spawn time. If you embed team-specific instructions directly in an agent file, they'll show up in standalone invocations where they don't belong and will confuse the agent's behavior outside the team context.

## Manifest and Source Control

The manifest file (`.claude/.agent-team-manifest`) tracks which version of each file was last installed.

**Per-developer setups:** Add `.claude/.agent-team-manifest` to `.gitignore`. Each developer manages their own customizations independently.

**Team-shared configurations:** Commit `.claude/.agent-team-manifest` alongside your customized agent files. This tells the installer which files were intentionally modified, preventing false conflict prompts when teammates pull your customizations and re-run the installer.

## How Worktree Isolation Works

The `/team` skill injects `isolation: worktree` when spawning each teammate. This is a native Claude Code field — Claude Code automatically:
- Creates a unique worktree directory for each agent
- Gives each agent an isolated working environment
- Cleans up worktrees on session exit

Agents do not need to manage git worktrees manually. The `worktree.md` protocol file covers only the communication layer (MERGE_CONFLICT messages, escalation rules).

## Repository Structure

```
bovorasr/claude-agents/
├── agents/                      # Agent role definitions
│   ├── architect.md
│   ├── product-owner.md
│   ├── retro-coordinator.md     # Retrospective facilitator
│   ├── ux.md
│   ├── senior-dev.md
│   ├── junior-dev.md
│   └── merge-specialist.md
├── skills/                      # Slash command definitions
│   └── team/
│       ├── SKILL.md             # /team orchestrator
│       ├── retro-protocol.md    # Retrospective protocol
│       ├── retro-extractor.sh   # Transcript extraction script
│       ├── worktree.md          # Coordination protocol
│       └── trifecta.md          # Trifecta deliberation protocol
├── install.sh                   # This installer
├── agent-team.md                # Design document
└── README.md
```

The `agents/` and `skills/` directories mirror the `.claude/` target structure. The installer prepends `.claude/` when copying.
