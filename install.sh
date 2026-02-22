#!/usr/bin/env bash
set -euo pipefail

REPO="bovorasr/claude-agents"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

FILES=(
  "agents/architect.md"
  "agents/product-owner.md"
  "agents/retro-coordinator.md"
  "agents/ux.md"
  "agents/senior-dev.md"
  "agents/junior-dev.md"
  "agents/merge-specialist.md"
  "skills/team/SKILL.md"
  "skills/team/retro-protocol.md"
  "skills/team/retro-extractor.sh"
  "skills/team/worktree.md"
  "skills/team/trifecta.md"
)

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "ERROR: no sha256 tool found (tried shasum, sha256sum)" >&2
    exit 1
  fi
}

# Write CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 and required Bash permissions
# into a settings.json file. Uses jq if available; creates a fresh file without
# it; prints manual instructions if jq is missing and the file already exists.
#
# Required Bash permissions:
#   cat   — !cat inline commands in SKILL.md at invocation time
#   echo  — writing/clearing the agent tracking file
#   bash .claude/skills/team/retro-extractor.sh — running the retro extractor
#   mv    — atomic rename in the log prepend step
#   rm    — cleanup of temp files after prepend
REQUIRED_PERMISSIONS='["Bash(cat:*)","Bash(echo:*)","Bash(bash .claude/skills/team/retro-extractor.sh:*)","Bash(mv:*)","Bash(rm:*)"]'

write_flag() {
  local settings_file="$1"
  local dir
  dir="$(dirname "$settings_file")"
  if command -v jq >/dev/null 2>&1; then
    mkdir -p "$dir"
    if [ -f "$settings_file" ]; then
      local tmp
      tmp="$(mktemp)"
      jq --argjson perms "$REQUIRED_PERMISSIONS" \
        '.env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1" |
         .permissions.allow = ((.permissions.allow // []) + $perms | unique)' \
        "$settings_file" > "$tmp"
      mv "$tmp" "$settings_file"
    else
      printf '{\n  "env": {\n    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"\n  },\n  "permissions": {\n    "allow": %s\n  }\n}\n' "$REQUIRED_PERMISSIONS" > "$settings_file"
    fi
    echo "  [set]        ${settings_file}"
  elif [ ! -f "$settings_file" ]; then
    mkdir -p "$dir"
    printf '{\n  "env": {\n    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"\n  },\n  "permissions": {\n    "allow": %s\n  }\n}\n' "$REQUIRED_PERMISSIONS" > "$settings_file"
    echo "  [set]        ${settings_file}"
  else
    echo "  [jq missing] Add this to ${settings_file} manually:"
    echo '               "env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}'
    echo "               \"permissions\": {\"allow\": ${REQUIRED_PERMISSIONS}}"
  fi
}

# Prompt the user to enable the flag + permission in a given settings.json,
# unless both are already present. Skips the prompt when non-interactive.
enable_flag() {
  local settings_file="$1"
  local label="$2"
  local has_flag=false has_perm=false
  if [ -f "$settings_file" ]; then
    grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$settings_file" 2>/dev/null && has_flag=true
    # Check for the retro-extractor permission as a proxy for all required permissions
    grep -qF 'retro-extractor' "$settings_file" 2>/dev/null && has_perm=true
  fi
  if [ "$has_flag" = true ] && [ "$has_perm" = true ]; then
    echo "  [set]        already configured in ${label}"
    return
  fi
  if [ "$INTERACTIVE" = true ]; then
    printf "  Enable CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS + required Bash permissions in %s? [y/N] " "$label"
    read -r _flag_answer < /dev/tty
    case "$_flag_answer" in
      y|Y|yes|YES) write_flag "$settings_file" ;;
      *) echo "  [skipped]    see README Prerequisites for manual setup instructions" ;;
    esac
  else
    echo "  [manual]     see README Prerequisites for required settings"
    echo "               or re-run this installer interactively"
  fi
}

# Detect TTY availability for interactive prompts
if [ -c /dev/tty ]; then
  INTERACTIVE=true
else
  INTERACTIVE=false
fi

# ---------------------------------------------------------------------------
# Determine install directory — project (.claude/) or global (~/.claude/)
# ---------------------------------------------------------------------------
if [ -d ".claude" ]; then
  INSTALL_DIR="$(pwd)/.claude"
  echo "Found .claude/ in current directory."
  echo "Installing into: ${INSTALL_DIR}/"
  echo ""
else
  echo "No .claude/ directory found in the current directory."
  echo ""
  if [ "$INTERACTIVE" = true ]; then
    printf "  Create .claude/ here and install? [y/N] "
    read -r _here_answer < /dev/tty
    case "$_here_answer" in
      y|Y|yes|YES)
        INSTALL_DIR="$(pwd)/.claude"
        echo "  Installing into: ${INSTALL_DIR}/"
        echo ""
        ;;
      *)
        printf "  Install globally to ~/.claude/ instead? [y/N] "
        read -r _global_answer < /dev/tty
        case "$_global_answer" in
          y|Y|yes|YES)
            INSTALL_DIR="${HOME}/.claude"
            echo "  Installing into: ${INSTALL_DIR}/"
            echo ""
            ;;
          *)
            echo "  Aborted."
            exit 0
            ;;
        esac
        ;;
    esac
  else
    echo "ERROR: No .claude/ directory found and no TTY available for prompting." >&2
    echo "Create a .claude/ directory first, or run the installer interactively." >&2
    exit 1
  fi
fi

MANIFEST_FILE="${INSTALL_DIR}/.agent-team-manifest"

# ---------------------------------------------------------------------------
# Summary counters (exported so handle_conflict can update them)
# ---------------------------------------------------------------------------
COUNT_INSTALLED=0
COUNT_UPDATED=0
COUNT_SKIPPED=0
COUNT_CONFLICTS=0

# ---------------------------------------------------------------------------
# Interactive conflict handler — must be defined before main flow
# ---------------------------------------------------------------------------
handle_conflict() {
  local file="$1"
  local target="$2"
  local tmp_file="$3"
  local upstream_hash="$4"

  while true; do
    echo ""
    echo "  Conflict: ${file}"
    echo "  Your local version differs from both your last install and the upstream."
    printf "  [o]verwrite  [s]kip  [d]iff  [b]ackup+overwrite: "
    if ! read -r choice < /dev/tty 2>/dev/null; then
      echo ""
      echo "    -> /dev/tty unavailable: keeping local version"
      echo "    -> Re-run in a terminal for interactive resolution"
      local local_hash
      local_hash="$(sha256 "$target")"
      echo "${local_hash}  ${file}" >> "$MANIFEST_FILE"
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
      COUNT_CONFLICTS=$((COUNT_CONFLICTS + 1))
      return
    fi

    case "$choice" in
      o|O)
        cp "$tmp_file" "$target"
        echo "${upstream_hash}  ${file}" >> "$MANIFEST_FILE"
        echo "    -> Overwritten with upstream"
        COUNT_UPDATED=$((COUNT_UPDATED + 1))
        return
        ;;
      s|S)
        local local_hash
        local_hash="$(sha256 "$target")"
        echo "${local_hash}  ${file}" >> "$MANIFEST_FILE"
        echo "    -> Kept local version (conflict will re-appear on next run)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        COUNT_CONFLICTS=$((COUNT_CONFLICTS + 1))
        return
        ;;
      d|D)
        echo ""
        diff -u "$target" "$tmp_file" || true
        echo ""
        # Loop back to re-prompt
        ;;
      b|B)
        cp "$target" "${target}.bak"
        cp "$tmp_file" "$target"
        echo "${upstream_hash}  ${file}" >> "$MANIFEST_FILE"
        echo "    -> Backed up to ${target}.bak, overwritten with upstream"
        COUNT_UPDATED=$((COUNT_UPDATED + 1))
        return
        ;;
      *)
        echo "    -> Please enter o, s, d, or b"
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Step 1: Read old manifest content into memory
# ---------------------------------------------------------------------------
OLD_MANIFEST_CONTENT=""
if [ -f "$MANIFEST_FILE" ]; then
  OLD_MANIFEST_CONTENT="$(cat "$MANIFEST_FILE")"
fi

# ---------------------------------------------------------------------------
# Step 2: Download all files to a temp directory (fail fast — no partial state)
# ---------------------------------------------------------------------------
WORK_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$WORK_TMPDIR"' EXIT

echo "Downloading files..."
for file in "${FILES[@]}"; do
  url="${BASE_URL}/${file}"
  dest="${WORK_TMPDIR}/${file}"
  mkdir -p "$(dirname "$dest")"
  if ! curl -fsSL "$url" -o "$dest"; then
    echo "ERROR: failed to download ${url}" >&2
    exit 1
  fi
done
echo "All files downloaded."
echo ""

# ---------------------------------------------------------------------------
# Step 3: Process each file — truncate manifest first, then append per file
# ---------------------------------------------------------------------------
mkdir -p "${INSTALL_DIR}"
> "$MANIFEST_FILE"

for file in "${FILES[@]}"; do
  target="${INSTALL_DIR}/${file}"
  tmp_file="${WORK_TMPDIR}/${file}"

  upstream_hash="$(sha256 "$tmp_file")"
  manifest_hash="$(echo "$OLD_MANIFEST_CONTENT" | grep -F " ${file}" 2>/dev/null | awk '{print $1}' | head -1 || echo "")"

  if [ ! -f "$target" ]; then
    # File doesn't exist locally → install
    mkdir -p "$(dirname "$target")"
    cp "$tmp_file" "$target"
    echo "${upstream_hash}  ${file}" >> "$MANIFEST_FILE"
    echo "  [installed]  ${file}"
    COUNT_INSTALLED=$((COUNT_INSTALLED + 1))

  elif [ -z "$manifest_hash" ]; then
    # No manifest entry — file existed before we started tracking
    local_hash="$(sha256 "$target")"
    if [ "$local_hash" = "$upstream_hash" ]; then
      # Local matches upstream — register and move on
      echo "${upstream_hash}  ${file}" >> "$MANIFEST_FILE"
      echo "  [unchanged]  ${file}"
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
      # Differs from upstream with no history — treat conservatively
      if [ "$INTERACTIVE" = true ]; then
        handle_conflict "$file" "$target" "$tmp_file" "$upstream_hash"
      else
        echo "  [kept-local] ${file} (no install record; non-interactive: skipping)"
        local_hash2="$(sha256 "$target")"
        echo "${local_hash2}  ${file}" >> "$MANIFEST_FILE"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        COUNT_CONFLICTS=$((COUNT_CONFLICTS + 1))
      fi
    fi

  else
    local_hash="$(sha256 "$target")"

    if [ "$local_hash" = "$manifest_hash" ] && [ "$manifest_hash" = "$upstream_hash" ]; then
      # Local == manifest == upstream: nothing changed
      echo "${upstream_hash}  ${file}" >> "$MANIFEST_FILE"
      echo "  [unchanged]  ${file}"
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))

    elif [ "$local_hash" = "$manifest_hash" ] && [ "$manifest_hash" != "$upstream_hash" ]; then
      # User hasn't touched it, upstream has a new version → auto-update
      cp "$tmp_file" "$target"
      echo "${upstream_hash}  ${file}" >> "$MANIFEST_FILE"
      echo "  [updated]    ${file}"
      COUNT_UPDATED=$((COUNT_UPDATED + 1))

    elif [ "$local_hash" != "$manifest_hash" ] && [ "$manifest_hash" = "$upstream_hash" ]; then
      # User modified locally, upstream unchanged → preserve local
      echo "${local_hash}  ${file}" >> "$MANIFEST_FILE"
      echo "  [kept-local] ${file} (local modifications preserved)"
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))

    else
      # local != manifest AND upstream != manifest → both sides changed
      if [ "$INTERACTIVE" = true ]; then
        handle_conflict "$file" "$target" "$tmp_file" "$upstream_hash"
      else
        echo "  [conflict]   ${file} (non-interactive: keeping local)"
        echo "${local_hash}  ${file}" >> "$MANIFEST_FILE"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        COUNT_CONFLICTS=$((COUNT_CONFLICTS + 1))
      fi
    fi
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Done. Installed to: ${INSTALL_DIR}/"
echo "  Installed:  ${COUNT_INSTALLED}"
echo "  Updated:    ${COUNT_UPDATED}"
echo "  Unchanged:  ${COUNT_SKIPPED}"
if [ "$COUNT_CONFLICTS" -gt 0 ]; then
  echo "  Conflicts skipped (non-interactive): ${COUNT_CONFLICTS}"
fi

# ---------------------------------------------------------------------------
# Step 4: Offer to enable the required flag + permissions
# ---------------------------------------------------------------------------
echo ""
echo "Configure /team requirements (experimental flag + Bash permissions):"
enable_flag "${INSTALL_DIR}/settings.json" "${INSTALL_DIR}/settings.json"

echo ""
echo "Usage:"
echo "  /team <describe what you want to build>"
echo ""
echo "To update later, re-run the same install command from the same directory."
