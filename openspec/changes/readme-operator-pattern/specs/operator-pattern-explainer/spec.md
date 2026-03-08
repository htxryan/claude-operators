## ADDED Requirements

### Requirement: Operator pattern section exists in README
The README SHALL contain a section explaining the "operator" pattern (agent-as-tool) placed immediately after the project description paragraph and before the "## Plugins" section.

#### Scenario: Section is present and correctly positioned
- **WHEN** a reader opens README.md
- **THEN** the first `##` section after the opening description paragraph SHALL be about the operator pattern

### Requirement: Section explains the problem
The section SHALL explain what problem the operator pattern solves: that AI agents running CLI tools directly in the main context leads to inconsistency, safety risks, and context pollution.

#### Scenario: Problem statement is present
- **WHEN** a reader reads the operator pattern section
- **THEN** they SHALL find a clear explanation of why direct CLI execution by the main agent is problematic

### Requirement: Section explains the mechanism
The section SHALL briefly describe how the pattern works: CLI commands are intercepted and routed to specialized subagents that have focused context and permissions.

#### Scenario: Mechanism is described
- **WHEN** a reader reads the operator pattern section
- **THEN** they SHALL understand that hooks intercept commands and delegate to subagents

### Requirement: Section presents key benefits
The section SHALL present concrete benefits of the pattern including at least: isolation/safety, consistency, and composability.

#### Scenario: Benefits are enumerated
- **WHEN** a reader reads the operator pattern section
- **THEN** they SHALL find at least three distinct benefits with brief explanations grounded in practical examples

### Requirement: Section is concise and scannable
The section SHALL be no longer than approximately 30 lines and SHALL use headers or bullet points for scannability.

#### Scenario: Length and format
- **WHEN** measuring the operator pattern section
- **THEN** it SHALL be approximately 20-30 lines and use structured formatting (bullets, bold, or sub-headers)
