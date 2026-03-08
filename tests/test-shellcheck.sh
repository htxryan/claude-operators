#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# ---------------------------------------------------------------------------
# ShellCheck lint — runs shellcheck on all .sh files in the repo
# ---------------------------------------------------------------------------

# Skip gracefully if shellcheck is not installed (local dev)
if ! command -v shellcheck &>/dev/null; then
  echo "# shellcheck not installed — skipping (install via: brew install shellcheck)"
  echo ""
  echo "# Tests: 0  Passed: 0  Failed: 0"
  exit 0
fi

while IFS= read -r sh_file; do
  rel="${sh_file#"$REPO_ROOT"/}"
  output=$(shellcheck -S warning "$sh_file" 2>&1) || true
  if [ -z "$output" ]; then
    pass "shellcheck: $rel"
  else
    fail "shellcheck: $rel"
    echo "$output"
  fi
done < <(find "$REPO_ROOT" -name '*.sh' -type f)

# ---------------------------------------------------------------------------
summary
