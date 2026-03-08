#!/usr/bin/env bash
# Claude Code SubagentStart/SubagentStop hook: tracks active subagents via marker files.
# Markers are scoped to the current session ID so they never leak across sessions.
# Uses a shared temp directory so all operator plugins can check subagent status.
#
# Usage:
#   SessionStart:  track-subagent.sh reset
#   SubagentStart: track-subagent.sh start
#   SubagentStop:  track-subagent.sh stop

set -euo pipefail

ACTION="${1:?Usage: track-subagent.sh <start|stop|reset>}"

MARKER_BASE="${TMPDIR:-/tmp}/claude-operator-system/active-subagents"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Reset: wipe ALL session dirs. Called on SessionStart to clear any stale state.
if [ "$ACTION" = "reset" ]; then
  rm -rf "$MARKER_BASE"
  exit 0
fi

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

MARKER_DIR="$MARKER_BASE/$SESSION_ID"
mkdir -p "$MARKER_DIR"

AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
if [ -z "$AGENT_ID" ]; then
  exit 0
fi

case "$ACTION" in
  start)
    touch "$MARKER_DIR/$AGENT_ID"
    ;;
  stop)
    rm -f "$MARKER_DIR/$AGENT_ID"
    ;;
esac

exit 0
