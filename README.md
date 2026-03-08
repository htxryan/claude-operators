# Claude Operators

A collection of Claude Code plugins that enforce CLI tool usage through operator subagents. Each plugin guards specific CLI commands and redirects to specialized subagents for safe, consistent execution.

## Plugins

| Plugin | CLI Guards | Operator | Description |
|--------|-----------|----------|-------------|
| `operator-system` | `git` | git-operator | Base infrastructure + git operator + create-operator skill |
| `github-operator` | `gh` | github-operator | GitHub CLI operations (PRs, issues, releases) |
| `bun-operator` | `bun`, `bunx` | bun-operator | Bun package manager and runtime operations |
| `cloudflare-wrangler-operator` | `wrangler` | cloudflare-wrangler-operator | Cloudflare Workers, KV, R2, D1, and deployments |
| `drizzle-operator` | `drizzle-kit` | drizzle-operator | Drizzle ORM migrations, schema push, and studio |
| `neon-operator` | `neonctl` | neon-operator | Neon Postgres branches, connections, and projects |

## How It Works

Each plugin uses Claude Code hooks to intercept Bash tool calls. When a guarded CLI command is detected in the main agent context, the hook blocks execution and instructs the agent to use the corresponding operator subagent instead.

The **operator-system** plugin provides the shared infrastructure:
- **PreToolUse hook** (`enforce-operator.sh`): Checks commands against the operator map and blocks direct CLI usage
- **Session/Subagent lifecycle hooks** (`track-subagent.sh`): Tracks active subagents via marker files so operator subagents can freely execute their own CLI commands
- **git-operator agent**: The foundational git operator
- **create-operator skill**: A scaffolding command to create new operator subagents

Individual operator plugins (github, bun, cloudflare, drizzle, neon) each provide:
- Their own `enforce-operator.sh` hook to guard their specific CLI commands
- An agent markdown file defining the operator subagent behavior
- An `operator-map.json` mapping CLI commands to operator names

## Installation

Install the `operator-system` base plugin first, then add any operator plugins you need:

```
operator-system          (required - base infrastructure)
github-operator          (optional)
bun-operator             (optional)
cloudflare-wrangler-operator  (optional)
drizzle-operator         (optional)
neon-operator            (optional)
```

## Creating Custom Operators

Use the `create-operator` skill (provided by `operator-system`) to scaffold new operators:

```
/create-operator kubectl
```

This creates the agent file and hook guard entries in your project's `.claude/` directory.

## Project-Local Overrides

Each plugin reads both its own `config/operator-map.json` and a project-local `.claude/operator-map.json`. This lets projects add custom CLI-to-operator mappings without modifying the plugins.

## Subagent Tracking: Why It Exists and How It Works

### The Problem

Claude Code hooks have a fundamental limitation: **a `PreToolUse` hook cannot determine which agent is making the tool call.** The hook receives the tool name and input, the session ID, and nothing else — no agent ID, no agent type, no indication of whether the call originates from the main conversation agent or from a subagent.

This creates a catch-22 for operator enforcement. When the main agent tries to run `git push`, the hook correctly blocks it and says "use the git-operator subagent instead." But when git-operator then runs `git push` itself, **the exact same hook fires with the exact same information**, and it would block the subagent too — making the operator pattern completely non-functional.

### The Workaround

The `operator-system` plugin uses Claude Code's `SubagentStart` and `SubagentStop` lifecycle hooks to maintain marker files that track whether any subagent is currently active:

```
SessionStart  → track-subagent.sh reset    # Clear all stale markers
SubagentStart → track-subagent.sh start    # Create marker file for this agent
SubagentStop  → track-subagent.sh stop     # Remove marker file for this agent
```

Markers are stored in a shared temp directory scoped by session ID:

```
${TMPDIR}/claude-operator-system/active-subagents/${SESSION_ID}/${AGENT_ID}
```

The `enforce-operator.sh` hook checks this directory **before** inspecting the command. If any marker file exists for the current session, the hook exits early and allows the command through. If no markers exist, the hook proceeds with its normal CLI blocking logic.

### Known Limitations

This is a best-effort workaround, not a proper solution. Be aware of these tradeoffs:

1. **All-or-nothing subagent bypass.** When _any_ subagent is active, _all_ guarded CLI commands are allowed through. If `git-operator` is running, a stray `wrangler deploy` command inside it would not be blocked. The hook cannot distinguish which subagent is making the call, so it has to allow everything. In practice this is rarely a problem because subagents are purpose-built and don't run unrelated CLIs, but the enforcement boundary is technically open while any subagent is active.

2. **Stale markers on crash.** If a subagent is terminated abnormally (process kill, OOM, etc.) without triggering the `SubagentStop` hook, its marker file persists. This means the enforcement hook would continue allowing all commands through until the next `SessionStart` reset clears stale markers. Within a single session, a crash could leave the guard down for the remainder of that session.

3. **Race conditions.** There is a small window between when `SubagentStart` fires and when the marker file is written, and similarly between `SubagentStop` and marker removal. In practice, these windows are negligible because hook scripts execute synchronously before the tool call proceeds, but they exist in theory.

4. **Session boundary is the only cleanup mechanism.** The `SessionStart` hook does a `rm -rf` of the entire marker directory. This is a blunt instrument — it works well for its purpose, but there is no periodic cleanup or TTL-based expiry. Long-running sessions that spawn and crash many subagents could accumulate stale markers (though the `SubagentStop` hook handles the normal case).

### What Would Fix This

The ideal solution would be for Claude Code to include an `agent_id` or `agent_type` field in the `PreToolUse` hook input. This would let the hook check "is this call coming from git-operator?" and only allow `git` commands for that specific operator, while still blocking everything else. Until that capability exists in the hooks API, the marker file approach is the best available option.
