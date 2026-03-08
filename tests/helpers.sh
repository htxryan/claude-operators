#!/usr/bin/env bash
# Shared test helpers — lightweight TAP-style assertions.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Counters
_PASS=0
_FAIL=0
_TOTAL=0

pass() {
  ((_TOTAL++)) || true
  ((_PASS++)) || true
  printf "ok %d - %s\n" "$_TOTAL" "$1"
}

fail() {
  ((_TOTAL++)) || true
  ((_FAIL++)) || true
  printf "not ok %d - %s\n" "$_TOTAL" "$1"
}

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$msg"
  else
    fail "$msg (expected '$expected', got '$actual')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$msg"
  else
    fail "$msg (expected to contain '$needle')"
  fi
}

assert_exit() {
  local expected="$1"
  shift
  local actual
  set +e
  "$@" >/dev/null 2>&1
  actual=$?
  set -e
  if [ "$expected" -eq "$actual" ]; then
    pass "exit $expected: $*"
  else
    fail "exit $expected: $* (got exit $actual)"
  fi
}

assert_exit_stdin() {
  local expected="$1" input="$2"
  shift 2
  local actual
  set +e
  echo "$input" | "$@" >/dev/null 2>&1
  actual=$?
  set -e
  if [ "$expected" -eq "$actual" ]; then
    pass "exit $expected: $*"
  else
    fail "exit $expected: $* (got exit $actual)"
  fi
}

assert_file_exists() {
  local path="$1" msg="${2:-file exists: $1}"
  if [ -f "$path" ]; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_dir_exists() {
  local path="$1" msg="${2:-dir exists: $1}"
  if [ -d "$path" ]; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_file_not_exists() {
  local path="$1" msg="${2:-file does not exist: $1}"
  if [ ! -f "$path" ]; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_dir_not_exists() {
  local path="$1" msg="${2:-dir does not exist: $1}"
  if [ ! -d "$path" ]; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_file_executable() {
  local path="$1" msg="${2:-file executable: $1}"
  if [ -x "$path" ]; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

summary() {
  echo ""
  echo "# Tests: $_TOTAL  Passed: $_PASS  Failed: $_FAIL"
  if [ "$_FAIL" -gt 0 ]; then
    exit 1
  fi
}
