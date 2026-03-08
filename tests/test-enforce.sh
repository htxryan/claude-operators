#!/usr/bin/env bash
# Tests for enforce-operator.sh behavioral enforcement logic.
# Verifies that each plugin blocks its guarded CLIs, allows non-guarded
# commands, respects active subagent markers, and handles edge cases.

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# ---------------------------------------------------------------------------
# Setup: isolate TMPDIR and CLAUDE_PROJECT_DIR so tests don't interfere
# with real state or pick up project-local operator maps.
# ---------------------------------------------------------------------------
TEST_TMPDIR="$(mktemp -d)"
export TMPDIR="$TEST_TMPDIR"
export CLAUDE_PROJECT_DIR="$TEST_TMPDIR/nonexistent-project"

cleanup() {
  rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

# Shorthand paths to each plugin's enforce-operator.sh
OPERATOR_SYSTEM="$REPO_ROOT/plugins/operator-system/scripts/enforce-operator.sh"
BUN_OPERATOR="$REPO_ROOT/plugins/bun-operator/scripts/enforce-operator.sh"
GITHUB_OPERATOR="$REPO_ROOT/plugins/github-operator/scripts/enforce-operator.sh"
WRANGLER_OPERATOR="$REPO_ROOT/plugins/cloudflare-wrangler-operator/scripts/enforce-operator.sh"
DRIZZLE_OPERATOR="$REPO_ROOT/plugins/drizzle-operator/scripts/enforce-operator.sh"
NEON_OPERATOR="$REPO_ROOT/plugins/neon-operator/scripts/enforce-operator.sh"

# ---------------------------------------------------------------------------
# 1. Blocks guarded command (operator-system)
# ---------------------------------------------------------------------------
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"git status"}}' \
  "$OPERATOR_SYSTEM"

# ---------------------------------------------------------------------------
# 2. Allows non-guarded command
# ---------------------------------------------------------------------------
assert_exit_stdin 0 \
  '{"session_id":"test","tool_input":{"command":"ls -la"}}' \
  "$OPERATOR_SYSTEM"

# ---------------------------------------------------------------------------
# 3. Allows when subagent is active
# ---------------------------------------------------------------------------
MARKER_DIR="$TEST_TMPDIR/claude-operator-system/active-subagents/test"
mkdir -p "$MARKER_DIR"
touch "$MARKER_DIR/some-agent"

assert_exit_stdin 0 \
  '{"session_id":"test","tool_input":{"command":"git status"}}' \
  "$OPERATOR_SYSTEM"

# ---------------------------------------------------------------------------
# 4. Blocks after subagent stops (marker removed)
# ---------------------------------------------------------------------------
rm -f "$MARKER_DIR/some-agent"
# Remove dir if empty (mirrors real cleanup behavior)
rmdir "$MARKER_DIR" 2>/dev/null || true

assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"git status"}}' \
  "$OPERATOR_SYSTEM"

# ---------------------------------------------------------------------------
# 5. Each plugin blocks its own CLIs
# ---------------------------------------------------------------------------

# bun-operator: bun
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"bun install"}}' \
  "$BUN_OPERATOR"

# bun-operator: bunx
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"bunx prettier ."}}' \
  "$BUN_OPERATOR"

# github-operator: gh
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"gh pr list"}}' \
  "$GITHUB_OPERATOR"

# cloudflare-wrangler-operator: wrangler
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"wrangler deploy"}}' \
  "$WRANGLER_OPERATOR"

# drizzle-operator: drizzle-kit
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"drizzle-kit generate"}}' \
  "$DRIZZLE_OPERATOR"

# neon-operator: neonctl
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"neonctl branches list"}}' \
  "$NEON_OPERATOR"

# ---------------------------------------------------------------------------
# 6. Handles pipes and chains
# ---------------------------------------------------------------------------

# Guarded CLI after a pipe should be blocked
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"echo foo | git log"}}' \
  "$OPERATOR_SYSTEM"

# "git" appearing as an argument (not a CLI invocation) should be allowed
assert_exit_stdin 0 \
  '{"session_id":"test","tool_input":{"command":"echo git"}}' \
  "$OPERATOR_SYSTEM"

# ---------------------------------------------------------------------------
# 7. Empty / missing command
# ---------------------------------------------------------------------------

# Missing command key
assert_exit_stdin 0 \
  '{"session_id":"test","tool_input":{}}' \
  "$OPERATOR_SYSTEM"

# Empty command string
assert_exit_stdin 0 \
  '{"session_id":"test","tool_input":{"command":""}}' \
  "$OPERATOR_SYSTEM"

# ---------------------------------------------------------------------------
summary
