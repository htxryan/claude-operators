## Why

The README currently explains *what* the plugins do and *how* they work, but doesn't explain *why* the "operator" pattern (agent-as-tool) is valuable. Visitors see a list of CLI wrappers without understanding the architectural insight that makes this approach effective. Adding a compelling section about the pattern itself—right after the project description—will help people understand why this is worth adopting and adapting to their own workflows.

## What Changes

- Add a new section to README.md immediately after the project description that explains the "operator" pattern (agent-as-tool)
- Cover why delegating CLI execution to specialized subagents is more reliable and safer than direct tool use
- Explain the key benefits: isolation, safety, consistency, and composability
- Position this as a general pattern people can apply, not just a feature of this repo

## Capabilities

### New Capabilities
- `operator-pattern-explainer`: README content explaining the agent-as-tool pattern—what it is, why it works, and why readers should consider implementing it

### Modified Capabilities

## Impact

- `README.md`: New section added after the opening description paragraph, before "## Plugins"
- No code changes, no API changes, no dependency changes
