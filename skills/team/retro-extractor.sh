#!/usr/bin/env bash
# retro-extractor.sh — Extract agent transcripts for retrospective
# Usage: bash .claude/skills/team/retro-extractor.sh <session-id>
set -euo pipefail

CLAUDE_SESSION_ID="${1:?Usage: retro-extractor.sh <session-id>}"
PROJECT_KEY=$(pwd | tr '/' '-')
SUBAGENTS="$HOME/.claude/projects/${PROJECT_KEY}/${CLAUDE_SESSION_ID}/subagents"
AGENTS_FILE=".claude/retro-session-agents.txt"

if [ ! -f "$AGENTS_FILE" ]; then
  echo "No agent tracking file found. Skipping retrospective extraction." >&2
  exit 0
fi

TOTAL_AGENTS=$(wc -l < "$AGENTS_FILE" | tr -d '[:space:]')
if [ "$TOTAL_AGENTS" -eq 0 ]; then
  echo "No agents recorded in tracking file. Skipping retrospective extraction." >&2
  exit 0
fi

PER_AGENT_WORDS=$((20000 / TOTAL_AGENTS))

# Write Python extraction script (idempotent)
cat << 'PYEOF' > .claude/retro-extract.py
import json, sys
path, max_words = sys.argv[1], int(sys.argv[2])
words, output = 0, []
with open(path) as f:
    for line in f:
        try:
            e = json.loads(line)
        except Exception:
            continue
        if e.get('type') not in ('user', 'assistant'):
            continue
        msg = e.get('message', {})
        role = msg.get('role', '')
        if role not in ('user', 'assistant'):
            continue
        content = msg.get('content', '')
        if isinstance(content, str):
            text = content.strip()
        elif isinstance(content, list):
            text = ' '.join(
                b.get('text', '') for b in content
                if isinstance(b, dict) and b.get('type') == 'text'
            ).strip()
        else:
            continue
        if not text:
            continue
        w = text.split()
        prefix = f"[{role.upper()}]: "
        if words + len(w) > max_words:
            output.append(prefix + ' '.join(w[:max_words - words]))
            break
        output.append(prefix + text)
        words += len(w)
print('\n\n'.join(output))
PYEOF

# Extract each agent's transcript and write to stdout
while IFS= read -r line; do
  role=$(echo "$line" | cut -d: -f1 | tr -d '[:space:]')
  agent_id=$(echo "$line" | cut -d: -f2 | tr -d '[:space:]')
  [ -z "$role" ] || [ -z "$agent_id" ] && continue
  JSONL="$SUBAGENTS/agent-${agent_id}.jsonl"
  if [ -f "$JSONL" ]; then
    TEXT=$(python3 .claude/retro-extract.py "$JSONL" "$PER_AGENT_WORDS")
    if [ -n "$TEXT" ]; then
      printf "\n\n### %s\n%s" "$role" "$TEXT"
    fi
  fi
done < "$AGENTS_FILE"

# Clean up Python helper (transcript output file and tracking file
# cleaned up by lead after successful prepend)
rm -f .claude/retro-extract.py
