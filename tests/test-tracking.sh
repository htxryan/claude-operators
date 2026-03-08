#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

SCRIPT="$REPO_ROOT/plugins/operator-system/scripts/track-subagent.sh"

# Setup: isolated TMPDIR so we don't touch real state
TEST_TMPDIR="$(mktemp -d)"
export TMPDIR="$TEST_TMPDIR"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

MARKER_BASE="$TMPDIR/claude-operator-system/active-subagents"

# ---------------------------------------------------------------------------
# 1. start creates marker file
# ---------------------------------------------------------------------------
echo '{"session_id":"test-session","agent_id":"agent-123"}' | "$SCRIPT" start
assert_file_exists "$MARKER_BASE/test-session/agent-123" "start creates marker file"

# clean up for next test
rm -rf "$MARKER_BASE"

# ---------------------------------------------------------------------------
# 2. stop removes marker file
# ---------------------------------------------------------------------------
echo '{"session_id":"test-session","agent_id":"agent-123"}' | "$SCRIPT" start
assert_file_exists "$MARKER_BASE/test-session/agent-123" "marker exists before stop"

echo '{"session_id":"test-session","agent_id":"agent-123"}' | "$SCRIPT" stop
assert_file_not_exists "$MARKER_BASE/test-session/agent-123" "stop removes marker file"

# clean up for next test
rm -rf "$MARKER_BASE"

# ---------------------------------------------------------------------------
# 3. reset wipes all markers
# ---------------------------------------------------------------------------
echo '{"session_id":"sess-a","agent_id":"agent-1"}' | "$SCRIPT" start
echo '{"session_id":"sess-a","agent_id":"agent-2"}' | "$SCRIPT" start
echo '{"session_id":"sess-b","agent_id":"agent-3"}' | "$SCRIPT" start
assert_file_exists "$MARKER_BASE/sess-a/agent-1" "pre-reset marker sess-a/agent-1"
assert_file_exists "$MARKER_BASE/sess-a/agent-2" "pre-reset marker sess-a/agent-2"
assert_file_exists "$MARKER_BASE/sess-b/agent-3" "pre-reset marker sess-b/agent-3"

echo '{}' | "$SCRIPT" reset
assert_dir_not_exists "$MARKER_BASE" "reset wipes entire active-subagents directory"

# ---------------------------------------------------------------------------
# 4. Missing session_id is no-op
# ---------------------------------------------------------------------------
assert_exit_stdin 0 '{}' "$SCRIPT" start
assert_dir_not_exists "$MARKER_BASE" "missing session_id creates no files"

# ---------------------------------------------------------------------------
# 5. Missing agent_id is no-op
# ---------------------------------------------------------------------------
echo '{"session_id":"test"}' | "$SCRIPT" start
assert_dir_exists "$MARKER_BASE/test" "session dir created even without agent_id"
# No marker file should exist inside the session dir
MARKER_COUNT=$(find "$MARKER_BASE/test" -type f | wc -l | tr -d ' ')
assert_eq "0" "$MARKER_COUNT" "missing agent_id creates no marker files"

# clean up for next test
rm -rf "$MARKER_BASE"

# ---------------------------------------------------------------------------
# 6. Multiple concurrent subagents
# ---------------------------------------------------------------------------
echo '{"session_id":"multi","agent_id":"alpha"}' | "$SCRIPT" start
echo '{"session_id":"multi","agent_id":"beta"}' | "$SCRIPT" start
assert_file_exists "$MARKER_BASE/multi/alpha" "concurrent agent alpha exists"
assert_file_exists "$MARKER_BASE/multi/beta" "concurrent agent beta exists"

echo '{"session_id":"multi","agent_id":"alpha"}' | "$SCRIPT" stop
assert_file_not_exists "$MARKER_BASE/multi/alpha" "stopped agent alpha removed"
assert_file_exists "$MARKER_BASE/multi/beta" "other agent beta still exists after stopping alpha"

summary
