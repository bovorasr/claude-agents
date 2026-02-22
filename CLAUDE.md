# Agent Role Definitions

Role definitions in `agents/` must be **context-agnostic**. The same file is used when invoking an agent standalone (`@architect`) and when `/team` spawns it during orchestration.

**Put in the role file:**
- The role's professional character, expertise, and point of view
- What it produces and what it refuses to do
- General methodologies and capabilities (how it approaches problems)
- Model, permission mode, and tool access

**Keep out of the role file:**
- References to `/team`, the trifecta, the lead, or team orchestration
- Task-specific instructions (integration steps, protocol phases, round formats)
- References to other specific roles by name as collaborators (e.g., "when the architect says...", "accept PO decisions")
- Any behavior that only makes sense inside the orchestrated team workflow

Coordination logic lives in `skills/team/` protocol files. The lead injects task-specific context into spawn payloads at runtime. If you embed team-specific instructions in a role file, they'll appear in standalone invocations where they don't belong.
