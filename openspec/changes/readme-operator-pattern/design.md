## Context

The README currently opens with a one-line project description and jumps straight into the plugin table and mechanics. There's no section explaining the "operator" pattern itself—why routing CLI execution through specialized subagents is a better architecture than letting the main agent run commands directly. This is a documentation-only change to a single file.

## Goals / Non-Goals

**Goals:**
- Add a section to README.md that explains the operator (agent-as-tool) pattern and why it's effective
- Position it immediately after the project description, before the Plugins table
- Make it persuasive: readers should understand why this pattern is worth adopting
- Keep it concise—this is a README section, not a whitepaper

**Non-Goals:**
- Rewriting or restructuring the rest of the README
- Adding diagrams or visual assets
- Creating separate documentation pages
- Changing any code or plugin behavior

## Decisions

**Section placement: after description, before Plugins table**
The pattern explanation should be the first thing people read after understanding what the project is. Placing it before the plugin table ensures visitors understand the "why" before the "what." Alternative considered: a separate PATTERN.md doc—rejected because most visitors won't click through; the README is where the pitch belongs.

**Tone: persuasive but grounded**
The section should explain the concrete benefits (isolation, safety, consistency, composability) with brief examples rather than abstract claims. Alternative considered: a more academic/formal treatment—rejected because the audience is practitioners who want to understand practical value quickly.

**Content structure: pattern name → problem → solution → key benefits**
Lead with naming the pattern, explain what problem it solves, describe the mechanism briefly, then list the benefits. This follows the "why should I care" reading pattern.

## Risks / Trade-offs

**[Too long, readers skip it]** → Keep to ~20-30 lines. Use headers and bullets for scannability.

**[Too abstract, doesn't connect to the project]** → Ground each benefit with a concrete example from the operators in this repo.
