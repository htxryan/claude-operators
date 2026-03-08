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
