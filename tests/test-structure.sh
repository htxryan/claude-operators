#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/helpers.sh"

# All plugin directories
ALL_PLUGINS=(
  bun-operator
  cloudflare-wrangler-operator
  drizzle-operator
  github-operator
  neon-operator
  operator-system
)

PLUGINS_DIR="$REPO_ROOT/plugins"

# ---------------------------------------------------------------------------
# 1. Required files exist for ALL plugins
# ---------------------------------------------------------------------------
for plugin in "${ALL_PLUGINS[@]}"; do
  dir="$PLUGINS_DIR/$plugin"

  assert_file_exists "$dir/.claude-plugin/plugin.json" \
    "$plugin: .claude-plugin/plugin.json exists"

  assert_file_exists "$dir/config/operator-map.json" \
    "$plugin: config/operator-map.json exists"

  assert_file_exists "$dir/hooks/hooks.json" \
    "$plugin: hooks/hooks.json exists"

  assert_file_exists "$dir/scripts/enforce-operator.sh" \
    "$plugin: scripts/enforce-operator.sh exists"

  # At least one .md file in agents/
  md_count=$(find "$dir/agents" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$md_count" -gt 0 ]; then
    pass "$plugin: has at least one agent .md file"
  else
    fail "$plugin: has at least one agent .md file (found $md_count)"
  fi
done

# ---------------------------------------------------------------------------
# 2. operator-system extras
# ---------------------------------------------------------------------------
assert_file_exists "$PLUGINS_DIR/operator-system/scripts/track-subagent.sh" \
  "operator-system: scripts/track-subagent.sh exists"

assert_file_exists "$PLUGINS_DIR/operator-system/skills/create-operator/SKILL.md" \
  "operator-system: skills/create-operator/SKILL.md exists"

# ---------------------------------------------------------------------------
# 3. JSON validity — all .json files parse with jq
# ---------------------------------------------------------------------------
for plugin in "${ALL_PLUGINS[@]}"; do
  dir="$PLUGINS_DIR/$plugin"

  for json_file in "$dir/.claude-plugin/plugin.json" \
                    "$dir/config/operator-map.json" \
                    "$dir/hooks/hooks.json"; do
    if [ -f "$json_file" ]; then
      if jq . "$json_file" >/dev/null 2>&1; then
        pass "valid JSON: $plugin/$(basename "$json_file")"
      else
        fail "valid JSON: $plugin/$(basename "$json_file")"
      fi
    fi
  done
done

# Root marketplace.json
if jq . "$REPO_ROOT/marketplace.json" >/dev/null 2>&1; then
  pass "valid JSON: marketplace.json"
else
  fail "valid JSON: marketplace.json"
fi

# ---------------------------------------------------------------------------
# 4. plugin.json schema — required fields
# ---------------------------------------------------------------------------
REQUIRED_PLUGIN_FIELDS=(name version description author keywords dependencies)

for plugin in "${ALL_PLUGINS[@]}"; do
  pjson="$PLUGINS_DIR/$plugin/.claude-plugin/plugin.json"
  if [ -f "$pjson" ]; then
    for field in "${REQUIRED_PLUGIN_FIELDS[@]}"; do
      if jq -e ".$field" "$pjson" >/dev/null 2>&1; then
        pass "$plugin: plugin.json has field '$field'"
      else
        fail "$plugin: plugin.json has field '$field'"
      fi
    done
  fi
done

# ---------------------------------------------------------------------------
# 5. hooks.json schema — PreToolUse with matcher and hooks
# ---------------------------------------------------------------------------
for plugin in "${ALL_PLUGINS[@]}"; do
  hjson="$PLUGINS_DIR/$plugin/hooks/hooks.json"
  if [ -f "$hjson" ]; then
    # Must have hooks.PreToolUse as an array
    ptu_len=$(jq '.hooks.PreToolUse | length' "$hjson" 2>/dev/null || echo "0")
    if [ "$ptu_len" -gt 0 ]; then
      pass "$plugin: hooks.json has PreToolUse array"
    else
      fail "$plugin: hooks.json has PreToolUse array"
    fi

    # Each entry must have matcher and hooks
    for i in $(seq 0 $((ptu_len - 1))); do
      has_matcher=$(jq -e ".hooks.PreToolUse[$i].matcher" "$hjson" >/dev/null 2>&1 && echo "yes" || echo "no")
      has_hooks=$(jq -e ".hooks.PreToolUse[$i].hooks | length > 0" "$hjson" >/dev/null 2>&1 && echo "yes" || echo "no")

      if [ "$has_matcher" = "yes" ]; then
        pass "$plugin: PreToolUse[$i] has 'matcher'"
      else
        fail "$plugin: PreToolUse[$i] has 'matcher'"
      fi

      if [ "$has_hooks" = "yes" ]; then
        pass "$plugin: PreToolUse[$i] has 'hooks' array"
      else
        fail "$plugin: PreToolUse[$i] has 'hooks' array"
      fi
    done
  fi
done

# ---------------------------------------------------------------------------
# 6. operator-system hooks.json extras
# ---------------------------------------------------------------------------
os_hooks="$PLUGINS_DIR/operator-system/hooks/hooks.json"
for hook_type in SessionStart SubagentStart SubagentStop; do
  arr_len=$(jq ".hooks.$hook_type | length" "$os_hooks" 2>/dev/null || echo "0")
  if [ "$arr_len" -gt 0 ]; then
    pass "operator-system: hooks.json has $hook_type array"
  else
    fail "operator-system: hooks.json has $hook_type array"
  fi
done

# ---------------------------------------------------------------------------
# 7. Shell scripts executable
# ---------------------------------------------------------------------------
while IFS= read -r sh_file; do
  rel="${sh_file#"$REPO_ROOT"/}"
  assert_file_executable "$sh_file" "executable: $rel"
done < <(find "$REPO_ROOT" -name '*.sh' -type f)

# ---------------------------------------------------------------------------
# 8. Shell script syntax
# ---------------------------------------------------------------------------
while IFS= read -r sh_file; do
  rel="${sh_file#"$REPO_ROOT"/}"
  if bash -n "$sh_file" 2>/dev/null; then
    pass "syntax ok: $rel"
  else
    fail "syntax ok: $rel"
  fi
done < <(find "$REPO_ROOT" -name '*.sh' -type f)

# ---------------------------------------------------------------------------
# 9. Agent frontmatter — name, description, model
# ---------------------------------------------------------------------------
while IFS= read -r md_file; do
  rel="${md_file#"$REPO_ROOT"/}"

  # Check file starts with ---
  first_line=$(head -1 "$md_file")
  if [ "$first_line" != "---" ]; then
    fail "$rel: has YAML frontmatter"
    continue
  fi

  # Extract frontmatter (between first and second ---)
  frontmatter=$(sed -n '2,/^---$/p' "$md_file" | sed '$d')

  for field in name description model; do
    if echo "$frontmatter" | grep -q "^${field}:"; then
      pass "$rel: frontmatter has '$field'"
    else
      fail "$rel: frontmatter has '$field'"
    fi
  done
done < <(find "$PLUGINS_DIR" -path '*/agents/*.md' -type f)

# ---------------------------------------------------------------------------
summary
