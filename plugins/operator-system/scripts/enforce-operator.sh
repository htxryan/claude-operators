#!/usr/bin/env bash
# Claude Code PreToolUse hook: block CLI commands in the main agent and
# redirect to the corresponding operator subagent.
#
# Reads operator maps from:
#   1. Plugin's own config/operator-map.json
#   2. Project-local .claude/operator-map.json (if present)
#
# Relies on track-subagent.sh (SubagentStart/SubagentStop) to maintain
# marker files that signal when a subagent is active.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_MAP="$SCRIPT_DIR/../config/operator-map.json"
PROJECT_MAP="${CLAUDE_PROJECT_DIR:-.}/.claude/operator-map.json"

INPUT=$(cat)

# If any subagent is currently active in this session, allow the command.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
MARKER_DIR="${TMPDIR:-/tmp}/claude-operator-system/active-subagents/${SESSION_ID}"
if [ -n "$SESSION_ID" ] && [ -d "$MARKER_DIR" ] && [ -n "$(ls -A "$MARKER_DIR" 2>/dev/null)" ]; then
  exit 0
fi

# Extract the Bash command being executed.
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Build a combined operator map from plugin + project-local maps.
COMBINED_MAP="{}"
if [ -f "$PLUGIN_MAP" ]; then
  COMBINED_MAP=$(jq -s '.[0] * .[1]' <(echo "$COMBINED_MAP") "$PLUGIN_MAP")
fi
if [ -f "$PROJECT_MAP" ]; then
  COMBINED_MAP=$(jq -s '.[0] * .[1]' <(echo "$COMBINED_MAP") "$PROJECT_MAP")
fi

# Check each CLI in the combined operator map against the command.
for CLI_NAME in $(echo "$COMBINED_MAP" | jq -r 'keys[]'); do
  if echo "$COMMAND" | grep -qE "(^|[|&;(]\s*)${CLI_NAME}(\s|$)"; then
    SUBAGENT_TYPE=$(echo "$COMBINED_MAP" | jq -r --arg cli "$CLI_NAME" '.[$cli]')
    cat >&2 <<MSG
BLOCKED: Do not run "${CLI_NAME}" commands directly. Use the "${SUBAGENT_TYPE}" subagent instead.
MSG
    exit 2
  fi
done

exit 0
