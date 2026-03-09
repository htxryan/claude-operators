#!/usr/bin/env bash
# Tests for enforce-operator.sh behavioral enforcement logic.
# Verifies that each plugin blocks its guarded CLIs, allows non-guarded
# commands, respects agent_type for subagent bypass, and handles edge cases.

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
BUN_OPERATOR="$REPO_ROOT/plugins/operator-bun/scripts/enforce-operator.sh"
GITHUB_OPERATOR="$REPO_ROOT/plugins/operator-github/scripts/enforce-operator.sh"
WRANGLER_OPERATOR="$REPO_ROOT/plugins/operator-cloudflare-wrangler/scripts/enforce-operator.sh"
DRIZZLE_OPERATOR="$REPO_ROOT/plugins/operator-drizzle/scripts/enforce-operator.sh"
NEON_OPERATOR="$REPO_ROOT/plugins/operator-neon/scripts/enforce-operator.sh"

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
# 3. Allows when agent_type is present (subagent context)
# ---------------------------------------------------------------------------
assert_exit_stdin 0 \
  '{"session_id":"test","agent_type":"git-operator","agent_id":"agent-123","tool_input":{"command":"git status"}}' \
  "$OPERATOR_SYSTEM"

# ---------------------------------------------------------------------------
# 4. Blocks when agent_type is absent (main agent context)
# ---------------------------------------------------------------------------
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"git status"}}' \
  "$OPERATOR_SYSTEM"

# ---------------------------------------------------------------------------
# 5. Each plugin blocks its own CLIs
# ---------------------------------------------------------------------------

# operator-bun: bun
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"bun install"}}' \
  "$BUN_OPERATOR"

# operator-bun: bunx
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"bunx prettier ."}}' \
  "$BUN_OPERATOR"

# operator-github: gh
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"gh pr list"}}' \
  "$GITHUB_OPERATOR"

# operator-cloudflare-wrangler: wrangler
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"wrangler deploy"}}' \
  "$WRANGLER_OPERATOR"

# operator-drizzle: drizzle-kit
assert_exit_stdin 2 \
  '{"session_id":"test","tool_input":{"command":"drizzle-kit generate"}}' \
  "$DRIZZLE_OPERATOR"

# operator-neon: neonctl
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
