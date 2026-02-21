# Claude Code Team Orchestration Pattern

## Overview

This pattern enables reusable role definitions (in `agents/*.md`) that work in
**both** standalone subagent context and as agent team member descriptions —
without embedding lead-specific coordination language in the role files.
Coordination logic lives exclusively in the `/team` skill.

## Design Goals

- `agents/*.md` files are pure domain role definitions, context-agnostic
- The `/team` command is the only place orchestration/coordination language lives
- Worktree isolation is mandatory for all teammates to prevent file collision
- Merge conflicts are escalated to the lead, not resolved ad-hoc by teammates
- The pattern degrades gracefully: agent files still work as regular subagents

---

## File Layout

```
.claude/
├── agents/
│   ├── architect.md           # Domain role only — no lead/team language
│   ├── senior-dev.md          # Domain role only
│   ├── junior-dev.md          # Domain role only
│   └── merge-specialist.md    # Domain role only
└── skills/
    └── team/
        ├── SKILL.md           # /team slash command — orchestration wrapper
        └── worktree.md        # Worktree protocol — create, merge, escalate
```

---

## Component Specifications

### `agents/*.md` — Role Definitions

These files define domain expertise only. They must not contain any language
about teams, leads, worktrees, or coordination. They should work identically
whether invoked as a standalone subagent or referenced as a teammate role.

**Format:**

```yaml
***
name: <role-name>
description: <When to use this agent — used for auto-delegation in subagent context>
model: sonnet        # or opus/haiku/inherit
tools: Read, Write, Bash, Grep, Glob
permissionMode: auto # or plan for higher-risk roles
***

<Domain-focused system prompt. Expertise, approach, coding standards, etc.
No mention of "lead", "teammates", "worktrees", or messaging.>
```

**Example — `agents/senior-dev.md`:**

```yaml
***
name: senior-dev
description: >
  Experienced full-stack developer. Use for implementing features, refactoring,
  writing tests, and reviewing code. Specializes in correctness and maintainability.
model: sonnet
tools: Read, Write, Bash, Grep, Glob
permissionMode: auto
***

You are a senior software developer with deep expertise in maintainable,
well-tested code. You write clear commit messages, prefer small focused
changes, and always verify your work compiles and tests pass before
considering a task complete.
```

**Example — `agents/merge-specialist.md`:**

```yaml
***
name: merge-specialist
description: >
  Resolves git merge conflicts. Invoke when a branch cannot be automatically
  merged. Requires: branch name and list of conflicting files.
model: opus
tools: Read, Write, Bash, Grep
permissionMode: plan
***

You are an expert at resolving merge conflicts without losing the intent of
either branch. When given a branch and conflicting files:
1. Read both sides of each conflict carefully
2. Understand the semantic intent of each change independently
3. Resolve preserving both intents where possible
4. If intents are irreconcilable, output a structured conflict summary and
   ask for priority guidance — do not guess
5. Commit the resolution with a message that explains the strategy used
```

---

### `skills/team/worktree.md` — Worktree Protocol

This file is injected into the `/team` skill prompt. It contains all
coordination language so that `agents/*.md` files remain clean.

```markdown
# Worktree Protocol for Teammates

## On Task Start
Before making any changes, create an isolated worktree for your task:
```bash
claude --worktree <task-slug>
# e.g. claude --worktree convert-auth-module
```
All implementation work must happen inside this worktree on its own branch.
Never modify files directly on main or the shared working branch.

## On Task Completion
When your implementation is complete:

1. Commit all changes with a clear message describing what was done
2. Attempt to merge back to the target branch:
   ```bash
   git fetch origin
   git merge --no-ff origin/main
   ```
3. **If merge succeeds**: remove the worktree, mark your task complete in the
   shared task list
4. **If merge fails**: do NOT attempt to resolve conflicts yourself. Send this
   exact message to the lead via the mailbox:

   ```
   MERGE_CONFLICT
   branch: <your-branch-name>
   task: <task-id>
   conflicting-files: <comma-separated list of files with conflicts>
   ```

   Then set your task status to `blocked` and wait for instruction.

## Conflict Escalation — Lead Responsibilities
When you receive a `MERGE_CONFLICT` message from a teammate:
1. Note the branch and conflicting files
2. Spawn the `merge-specialist` subagent, providing the branch name and file list
3. Wait for merge-specialist to complete and confirm resolution
4. Resume the blocked teammate or mark the task complete as appropriate
```

---

### `skills/team/SKILL.md` — The `/team` Command

```yaml
***
name: team
description: Spin up an agent team for a task using defined roles in agents/*.md
disable-model-invocation: true
argument-hint: "[task description and team composition, e.g. '3 senior devs to convert auth module to TypeScript']"
***

## Task
$ARGUMENTS

## Available Roles
The following role definitions are in `.claude/agents/`. Use these descriptions
to configure teammate spawn prompts — do not repeat or paraphrase them, treat
them as authoritative role specifications:

!`cat .claude/agents/*.md`

## Orchestration Instructions

1. **Plan first**: Before spawning any teammates, produce a task breakdown that
   assigns each task to a specific role, with explicit file ownership per task.
   No two tasks should touch the same file. Get approval before proceeding.

2. **Spawn teammates**: Use the role definitions above to configure each
   teammate's spawn prompt. Specify model, task scope, and file ownership.

3. **Inject worktree protocol**: Every teammate must receive the contents of
   `.claude/skills/team/worktree.md` as part of their instructions at spawn.
   Do not summarize it — inject it verbatim.

4. **Require plan approval**: Each teammate must submit a plan listing which
   files they intend to modify before making any changes. Do not approve plans
   with overlapping file ownership.

5. **Monitor the task list**: Watch for `MERGE_CONFLICT` messages in the
   mailbox. When received, spawn the `merge-specialist` subagent immediately.

6. **No nested teams**: You cannot spawn sub-teams. All delegation goes through
   you. Teammates may invoke subagents from `.claude/agents/` for focused work,
   but cannot spawn teammates of their own.
```

---

## Execution Flow

```
User: /team 3 senior devs to convert the PHP auth module to React

Lead (Opus)
  ├── Reads agents/*.md role definitions
  ├── Reads task description
  ├── Produces file-scoped task breakdown (awaits approval)
  ├── Approval granted
  ├── Spawns Teammate A (senior-dev, owns /auth/login.*)
  │     ├── Creates worktree: worktree-auth-login
  │     ├── Submits plan → Lead approves
  │     ├── Implements
  │     ├── Merge succeeds → marks task complete
  │     └── Removes worktree
  ├── Spawns Teammate B (senior-dev, owns /auth/session.*)
  │     ├── Creates worktree: worktree-auth-session
  │     ├── Submits plan → Lead approves
  │     ├── Implements
  │     ├── Merge FAILS → messages lead: MERGE_CONFLICT
  │     └── Sets status: blocked
  ├── Lead receives MERGE_CONFLICT
  │     └── Spawns merge-specialist subagent (branch, files)
  │           ├── Resolves conflict
  │           └── Commits resolution
  └── Lead marks Teammate B task complete
```

---

## Key Design Decisions

**Why is coordination language not in `agents/*.md`?**
Role files serve dual purpose: they are used as subagent definitions (where
there is no "lead") and as role descriptions for team spawning. Putting
`message the lead when X` in a role file breaks subagent usage semantics.
The `/team` skill is the single point where team coordination language is
introduced.

**Why `disable-model-invocation: true` on the `/team` skill?**
Spawning a team is a deliberate, high-cost action. This flag ensures Claude
never auto-invokes it; it only fires when you explicitly type `/team`.

**Why inject `worktree.md` verbatim into teammate spawn prompts?**
Teammates do not inherit the lead's conversation history. They only get what
is explicitly passed at spawn time. CLAUDE.md is inherited, but worktree
protocol is team-specific and should not be in CLAUDE.md.

**Why does the merge-specialist need `permissionMode: plan`?**
Merge conflict resolution is irreversible and high-risk. Forcing a plan step
gives the lead visibility into the resolution strategy before commits are made.

---

## Implementation Checklist

- [ ] Create `.claude/agents/architect.md`
- [ ] Create `.claude/agents/senior-dev.md`
- [ ] Create `.claude/agents/junior-dev.md`
- [ ] Create `.claude/agents/merge-specialist.md`
- [ ] Create `.claude/skills/team/worktree.md`
- [ ] Create `.claude/skills/team/SKILL.md`
- [ ] Verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_T
