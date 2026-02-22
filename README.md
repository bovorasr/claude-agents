# claude-agents

Reusable Claude Code agent definitions and skills for orchestrating teams of agents with worktree isolation, role-based delegation, and merge conflict escalation.

## Quick Install

From your project root:

```bash
curl -fsSL https://raw.githubusercontent.com/bovorasr/claude-agents/main/install.sh | bash
```

This installs the following into `.claude/`:

| File | Description |
|------|-------------|
| `.claude/agents/architect.md` | Systems thinker — design docs, interfaces, trade-off analyses. Never writes implementation code. |
| `.claude/agents/product-owner.md` | Delivery advocate — prioritizes user value, challenges scope, pushes for the minimum useful slice. Never writes code. |
| `.claude/agents/ux.md` | User experience advocate — flows, mental models, edge cases from a user perspective. Never writes code. |
| `.claude/agents/senior-dev.md` | Completes tested changes. Reads existing code first, matches style, runs tests before done. |
| `.claude/agents/junior-dev.md` | Precise task executor. Good at repetitive/scoped work. Flags ambiguity instead of improvising. |
| `.claude/agents/merge-specialist.md` | Classifies and resolves merge conflicts. Escalates contradictory conflicts with structured reports. |
| `.claude/skills/team/SKILL.md` | The `/team` slash command — orchestrates the other agents. |
| `.claude/skills/team/worktree.md` | Worktree coordination protocol — MERGE_CONFLICT format, escalation rules, lead responsibilities. |
| `.claude/skills/team/trifecta.md` | Trifecta deliberation protocol — deliberation loop, conflict templates, alignment doc format. |

## Prerequisites

Agent teams are currently experimental. Enable the feature by setting the environment variable:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Or add it to your project's `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

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
6. Report back when complete

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

## Updating

Re-run the same install command. The installer tracks a manifest at `.claude/.agent-team-manifest` to detect what's changed:

- **You haven't modified a file, upstream has** → auto-updated
- **You've modified a file, upstream unchanged** → your version kept
- **Both sides changed** → interactive conflict prompt with `[o]verwrite / [s]kip / [d]iff / [b]ackup`

In a CI or non-interactive environment, conflicts default to keeping your local version.

## Customizing Agent Definitions

The agent files in `.claude/agents/` are plain markdown. Edit them directly to adjust behavior, tools, models, or permission modes.

After customizing, the manifest records your local hash. If upstream changes, the installer will detect the conflict and prompt you rather than silently overwriting.

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
│   ├── ux.md
│   ├── senior-dev.md
│   ├── junior-dev.md
│   └── merge-specialist.md
├── skills/                      # Slash command definitions
│   └── team/
│       ├── SKILL.md             # /team orchestrator
│       ├── worktree.md          # Coordination protocol
│       └── trifecta.md          # Trifecta deliberation protocol
├── install.sh                   # This installer
├── agent-team.md                # Design document
└── README.md
```

The `agents/` and `skills/` directories mirror the `.claude/` target structure. The installer prepends `.claude/` when copying.
