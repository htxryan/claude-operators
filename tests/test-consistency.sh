#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# =============================================================================
# Cross-file invariant tests for the claude-operators repo.
# Validates that plugin metadata, agent files, marketplace listings,
# operator-maps, and dependency declarations are all consistent.
# =============================================================================

PLUGINS_DIR="$REPO_ROOT/plugins"
MARKETPLACE="$REPO_ROOT/marketplace.json"

# ---------------------------------------------------------------------------
# 1. Name alignment — directory name matches plugin.json name field
# ---------------------------------------------------------------------------
for dir in "$PLUGINS_DIR"/*/; do
  dir_name="$(basename "$dir")"
  plugin_json="$dir/.claude-plugin/plugin.json"
  if [ ! -f "$plugin_json" ]; then
    fail "name-alignment: $dir_name — plugin.json not found"
    continue
  fi
  json_name="$(jq -r '.name' "$plugin_json")"
  assert_eq "$dir_name" "$json_name" \
    "name-alignment: $dir_name matches plugin.json name"
done

# ---------------------------------------------------------------------------
# 2. Agent file exists matching plugin
#    - operator-system has agents/git-operator.md
#    - all others have agents/<dir-name>.md
# ---------------------------------------------------------------------------
for dir in "$PLUGINS_DIR"/*/; do
  dir_name="$(basename "$dir")"
  if [ "$dir_name" = "operator-system" ]; then
    assert_file_exists "$dir/agents/git-operator.md" \
      "agent-file: operator-system has agents/git-operator.md"
  else
    assert_file_exists "$dir/agents/${dir_name}.md" \
      "agent-file: $dir_name has agents/${dir_name}.md"
  fi
done

# ---------------------------------------------------------------------------
# 3. Marketplace coverage
#    a) Every plugins/ directory is listed in marketplace.json by name
#    b) Every marketplace.json entry path resolves to a real directory
# ---------------------------------------------------------------------------
marketplace_names="$(jq -r '.plugins[].name' "$MARKETPLACE")"

for dir in "$PLUGINS_DIR"/*/; do
  dir_name="$(basename "$dir")"
  if echo "$marketplace_names" | grep -qxF "$dir_name"; then
    pass "marketplace-coverage: $dir_name listed in marketplace.json"
  else
    fail "marketplace-coverage: $dir_name NOT listed in marketplace.json"
  fi
done

marketplace_paths="$(jq -r '.plugins[].path' "$MARKETPLACE")"
while IFS= read -r rel_path; do
  full_path="$REPO_ROOT/$rel_path"
  if [ -d "$full_path" ]; then
    pass "marketplace-path: $rel_path resolves to a real directory"
  else
    fail "marketplace-path: $rel_path does NOT resolve to a real directory"
  fi
done <<< "$marketplace_paths"

# ---------------------------------------------------------------------------
# 4. Operator-map references valid
#    Every value in every operator-map.json has a corresponding .md agent file
#    somewhere in plugins/*/agents/
# ---------------------------------------------------------------------------
all_agent_files="$(find "$PLUGINS_DIR" -path '*/agents/*.md' -exec basename {} .md \;)"

for map_file in "$PLUGINS_DIR"/*/config/operator-map.json; do
  plugin_name="$(basename "$(dirname "$(dirname "$map_file")")")"
  values="$(jq -r 'values[]' "$map_file" | sort -u)"
  while IFS= read -r agent_name; do
    [ -z "$agent_name" ] && continue
    if echo "$all_agent_files" | grep -qxF "$agent_name"; then
      pass "operator-map-ref: $plugin_name — $agent_name has agent file"
    else
      fail "operator-map-ref: $plugin_name — $agent_name has NO agent file"
    fi
  done <<< "$values"
done

# ---------------------------------------------------------------------------
# 5. Dependencies correct
#    - operator-system has dependencies: []
#    - all other plugins have dependencies: ["operator-system"]
# ---------------------------------------------------------------------------
for dir in "$PLUGINS_DIR"/*/; do
  dir_name="$(basename "$dir")"
  plugin_json="$dir/.claude-plugin/plugin.json"
  [ ! -f "$plugin_json" ] && continue

  deps="$(jq -c '.dependencies' "$plugin_json")"

  if [ "$dir_name" = "operator-system" ]; then
    assert_eq "[]" "$deps" \
      "dependencies: operator-system has empty dependencies"
  else
    assert_eq '["operator-system"]' "$deps" \
      "dependencies: $dir_name depends on operator-system"
  fi
done

# ---------------------------------------------------------------------------
# 6. No duplicate keys across operator-maps
#    Collect all keys from all operator-map.json files. No CLI command should
#    appear in more than one plugin's map.
# ---------------------------------------------------------------------------
all_keys_file="$(mktemp)"
trap 'rm -f "$all_keys_file"' EXIT

for map_file in "$PLUGINS_DIR"/*/config/operator-map.json; do
  jq -r 'keys[]' "$map_file" >> "$all_keys_file"
done

total_keys="$(wc -l < "$all_keys_file" | tr -d ' ')"
unique_keys="$(sort -u "$all_keys_file" | wc -l | tr -d ' ')"

if [ "$total_keys" -eq "$unique_keys" ]; then
  pass "no-duplicate-keys: all $total_keys operator-map keys are unique"
else
  # Find and report the duplicates
  dupes="$(sort "$all_keys_file" | uniq -d | tr '\n' ', ')"
  fail "no-duplicate-keys: duplicate keys found: ${dupes%, }"
fi

# ---------------------------------------------------------------------------
summary
