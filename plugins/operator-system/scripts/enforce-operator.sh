#!/usr/bin/env bash
# Claude Code PreToolUse hook: block CLI commands in the main agent and
# redirect to the corresponding operator subagent.
#
# Reads operator maps from:
#   1. Plugin's own config/operator-map.json
#   2. Project-local .claude/operator-map.json (if present)
#
# Uses the agent_type field from PreToolUse hook input (available since
# Claude Code 2.1.64) to distinguish main-agent calls from subagent calls.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_MAP="$SCRIPT_DIR/../config/operator-map.json"
PROJECT_MAP="${CLAUDE_PROJECT_DIR:-.}/.claude/operator-map.json"

INPUT=$(cat)

# If this call is coming from any subagent, allow it through.
# Subagents are purpose-built and should be free to run their CLI commands.
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
if [ -n "$AGENT_TYPE" ]; then
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
