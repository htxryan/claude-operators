---
description: Create a new operator subagent for a CLI tool and add its enforce-operator hook guard
disable-model-invocation: true
---

Create a new operator subagent for the specified CLI tool and register its hook guard.

## Input

$ARGUMENTS

Parse the input to identify:
- **CLI command(s)**: The command-line tool(s) to wrap (e.g., `kubectl`, `terraform`). If multiple related commands are given (e.g., `bun` / `bunx`), treat them as a single operator that handles both.
- **Operator name**: Derive as `<tool>-operator` using the primary CLI name (e.g., `kubectl-operator`, `terraform-operator`).

If the input is unclear, ask the user to clarify what CLI tool to wrap.

## Step 1: Research the CLI tool

Before writing the subagent, research the CLI tool so the operator file is accurate and useful:
- Run `<cli> --help` (or equivalent) to get the top-level command structure
- Identify the major subcommands / operation categories
- Note any common flags or patterns

## Step 2: Create the operator subagent file

Create `.claude/agents/<operator-name>.md` following the established pattern. Use existing operators in this plugin as reference (read one if needed to match the format exactly).

The file MUST include:

### Frontmatter (YAML)
```yaml
---
name: <operator-name>
description: "<1-2 sentence description of when to use this agent, followed by 5-6 examples in the established format>"
model: sonnet
color: <pick an unused color from: green, yellow, orange, red, blue, purple, cyan, magenta>
---
```

The `description` field must follow the established example format:
```
Use this agent when the user needs to <do X> via the <cli> CLI — including <list of operations>. This agent should be the default for ALL <domain> operations.

Examples:

- User: "<example request>"
  Assistant: "<example response>"
  (<What the agent does>)

... (5-6 examples covering common operations and proactive usage)
```

### Body content
Follow this structure (match the tone and style of existing operators):

1. **Opening line**: "You are an expert <domain> operator. Your sole purpose is to execute `<cli>` CLI operations and return only the most relevant, concise information."

2. **Core Principles** section:
   - Minimal Output
   - Execute, Don't Explain
   - Confirm Destructive Operations
   - Any tool-specific principle

3. **Operations Reference** section: Organized by category with bash code blocks showing key commands

4. **Response Formatting Rules** section: How to format output for different operation types

5. **Error Handling** section: Common errors and suggested fixes

6. **What NOT to Do** section: Standard prohibitions (no verbose output, no explanations, no filler, no repeating questions)

## Step 3: Add the hook guard(s)

Read or create `.claude/operator-map.json` and add new entries mapping each CLI command to the operator name.

Each entry is a key-value pair where the key is the CLI command and the value is the operator name:
```json
{
  "<cli-command>": "<operator-name>"
}
```

If wrapping multiple related CLIs (e.g., `bun` and `bunx`), add a separate entry for EACH command, all pointing to the same operator.

**Important**: Do NOT modify any existing entries in operator-map.json -- only add new entries.

## Step 4: Validate

1. Verify the new agent file exists and has correct frontmatter
2. Verify the hook entries were added to operator-map.json
3. Report a summary:

```
Operator created: <operator-name>

  Agent file:     .claude/agents/<operator-name>.md
  Hook guards:    <cli-command-1>, <cli-command-2>, ...
  Operator map:   .claude/operator-map.json

The main agent will now be blocked from running `<cli>` directly
and redirected to use the <operator-name> subagent instead.
```
