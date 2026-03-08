# Claude Operators

A collection of Claude Code plugins that enforce CLI tool usage through operator subagents. Each plugin guards specific CLI commands and redirects to specialized subagents for safe, consistent execution.

## Why the Operator Pattern?

AI agents can run CLI tools directly, but every command and its output consumes the main agent's context window. A handful of `git` or `gh` invocations can burn through context fast, forcing earlier compaction and degrading the agent's ability to track your actual task. The main agent also has broad permissions — there's no guardrail preventing a careless `git push --force` or `wrangler deploy` to the wrong environment.

The **operator pattern** (agent-as-tool) solves this by routing CLI execution through specialized subagents:

1. **Hooks intercept** guarded commands in the main agent context and block them
2. **The main agent delegates** to a purpose-built operator subagent instead
3. **The operator executes** with its own dedicated context window and returns a concise result

This gives you:

- **Context isolation** — The primary benefit. Each operator runs in its own context window, dedicated to a specific tool and task. CLI output, retries, and troubleshooting stay contained in the subagent. The main agent's context stays focused on your actual work, letting it run longer before requiring compaction.
- **Safety** — Operators have scoped permissions and built-in safeguards. The main agent can't accidentally force-push or deploy to production; each operator enforces its own guardrails.
- **Consistency** — Every `gh pr create` goes through the same operator with the same conventions. No variation depending on how the main agent decides to construct a command.
- **Composability** — Operators are modular plugins. Install only what you need, create custom operators for your own CLIs, and override mappings per-project.

This isn't specific to the operators in this repo — it's a general pattern you can apply to any CLI tool your agent needs to use.

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
- **PreToolUse hook** (`enforce-operator.sh`): Checks commands against the operator map and blocks direct CLI usage in the main agent, while allowing subagents through via the `agent_type` field
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

## How Subagent Bypass Works

When the main agent tries to run `git push`, the `PreToolUse` hook blocks it and says "use the git-operator subagent instead." When `git-operator` then runs `git push` itself, the same hook fires — but now the hook input includes `agent_type: "git-operator"`, so the hook allows it through.

This relies on the `agent_type` field that Claude Code includes in `PreToolUse` hook input when the call originates from a subagent (available since Claude Code 2.1.64). Main-agent calls have no `agent_type`, so they are subject to enforcement. Subagent calls include `agent_type`, so they are allowed through.

> **Requires Claude Code >= 2.1.64.** Earlier versions do not include `agent_type` in `PreToolUse` hook input.
