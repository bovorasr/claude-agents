# Worktree Coordination Protocol

This document defines the coordination protocol for agents working in parallel with worktree isolation. Native `isolation: worktree` (a built-in Claude Code field) handles directory creation, unique naming, and cleanup automatically — this protocol covers only the communication layer.

---

## MERGE_CONFLICT Message Format

When a merge fails, the affected teammate sends this exact structured message to the lead:

```
MERGE_CONFLICT

Agent: <your role name>
Task: <brief description of what you were implementing>
Branch context: <which files/areas you modified>

Conflict details:
<paste the merge conflict output or describe what failed>

Files affected:
- <path/to/file.ext>
- <path/to/other.ext>

Status: BLOCKED — awaiting merge resolution before continuing
```

---

## Escalation Rules

**When to send MERGE_CONFLICT:**
- A merge or rebase fails due to conflicts you cannot automatically resolve
- You are about to overwrite changes made by a parallel agent

**When NOT to send:**
- Simple file additions with no conflicts
- Conflicts in files you are solely responsible for
- Conflicts that are clearly trivial (you added a line, they added a different line in a different function — compose both)

**After sending:**
- Set your task status to blocked
- Do not attempt to continue or work around the conflict
- Wait for the lead to respond with resolution instructions

---

## Lead Responsibilities

When a MERGE_CONFLICT message arrives:

1. **Acknowledge** — reply to the blocked agent that you received it
2. **Spawn merge-specialist** — delegate the conflict files with both sets of changes
3. **Relay resolution** — once merge-specialist produces a resolved version, send it to the blocked agent with instructions to apply it and continue
4. **Resume teammate** — explicitly tell the blocked agent to un-block and resume

The lead does not resolve merge conflicts directly. That is the merge-specialist's role.

---

## No Manual Git Commands

Do not run `git worktree add`, `git worktree remove`, or manual branch management commands. The native `isolation: worktree` field handles the full worktree lifecycle — creation, unique path generation, and cleanup on session exit. Manual commands will conflict with this management.
