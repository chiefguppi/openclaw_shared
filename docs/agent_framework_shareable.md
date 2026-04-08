<!-- PUBLIC_SHARE: approved-for-public-repo -->

# Agent Framework

A shareable framework for building and governing multiple agents in an OpenClaw workspace or a similar agent-hosting environment.

## Scope
- Covers: agent roles, governance boundaries, packaging patterns, memory model, review model, and suggested filesystem layouts
- Does not cover: environment-specific secrets, trusted-channel identities, machine-specific paths, or local operational policy details

## Audience
- Primary maintainer: OpenClaw operators and workspace designers
- Primary reader: anyone designing a multi-agent workspace with an orchestrator and specialist agents

## Design Goals

- Support a small number of durable, high-value agents rather than a loose collection of prompts or personas
- Preserve one clear orchestrator role for intake, governance, and delegation
- Separate persona, expertise, authority, and memory so agent design stays maintainable
- Reuse common structures across agents
- Apply global trust and safety rules consistently across the system
- Allow specialist depth without letting every agent become over-privileged

## Recommended Architecture

Use a hub-and-specialists model:

- **Orchestrator agent** for intake, routing, synthesis, governance, and continuity
- **Specialist agents** for domain-specific execution and deep context
- **Optional persona overlays** for style and collaboration mode, without confusing style with authority
- **Shared governance layer** for trust, security, secrecy, approval rules, and publication controls
- **Domain context packs** for specialized knowledge, tools, and workflows

This model should cover most future needs while keeping the system understandable.

## Recommended Packaging Pattern

Prefer a self-contained, portable, minimally coupled, host-governed pattern for substantial specialist agents.

In practice, this means:
- keep domain logic, local documentation, scripts, data contracts, and project memory inside the agent or project folder
- keep global trust, safety, approval, and secrets-handling rules at the root governance layer
- let the root orchestrator host, route to, schedule, and review the specialist rather than embedding the specialist's entire operating model into root context files

Treat the root environment as the host and governor, and the specialist as a portable domain appliance.

Benefits:
- portability to another workspace or machine
- easier sanitization and sharing
- clearer boundaries between host governance and domain behavior
- less cross-project contamination of memory and instructions
- simpler testing, iteration, and eventual publication

This should be the default pattern for any agent that may later be exported, shared, or developed semi-independently.

## Core Agent Types

### 1. Orchestrator agent

Responsibilities:
- receive user requests
- classify task type and domain
- decide whether to handle directly or delegate
- enforce trust, security, and approval rules
- maintain continuity across workstreams
- synthesize or review specialist output

The orchestrator should remain broad, policy-aware, and less domain-specific than specialist agents.

### 2. Specialist agents

Responsibilities:
- operate in a defined domain
- use domain-specific context and playbooks
- produce focused analysis, plans, drafts, or execution within approved limits

Examples:
- 3D printing agent
- homelab or infrastructure agent
- research or synthesis agent
- documentation or publishing agent

### 3. Persona agents or overlays

Purpose:
- provide a distinct collaboration style or perspective
- shape tone, framing, or mode of thought
- not implicitly expand authority or tool access

Examples:
- shop buddy
- business strategist
- technical reviewer
- brainstorming partner

Persona should be treated separately from permissions and safety boundaries.

## Separation of Concerns

Keep these dimensions separate when designing an agent:

1. **Identity / persona**
2. **Domain expertise**
3. **Authority / permissions**
4. **Memory / context**

Do not collapse all four into a single blob file or prompt if avoidable.

## Governance Model

### Host-governed specialists

A self-contained specialist may define rich local behavior, but it should remain host-governed.

Root governance should continue to own:
- trust boundaries
- secret handling
- outbound communication rules
- approval requirements
- destructive-action safeguards
- publication or sharing controls

The specialist should own:
- domain logic
- local workflows
- domain-specific memory
- project file conventions
- scripts, references, and examples

This boundary keeps specialists portable without weakening system-wide safeguards.

### Global governance

Global governance should remain outside specialist folders and apply across the system.

Examples:
- trust boundaries
- prompt-injection safeguards
- secrets handling
- outbound-sharing restrictions
- document publication policy
- memory discipline
- approval requirements

Primary homes for these rules should be clearly documented in the host environment.

### Local specialization

Each agent may have local files describing:
- domain context
- role-specific operating guidance
- tools and workflows
- example outputs
- playbooks

Local specialization may refine behavior, but should not silently override global trust or safety rules.

## Permission Tiers

Define agent authority using a small number of tiers.

### Tier 1: Advisory
- analyze
- summarize
- brainstorm
- recommend
- no side effects

### Tier 2: Workspace
- write drafts or files inside the workspace
- prepare configs or structured outputs
- no external actions without approval

### Tier 3: Operational
- inspect systems or services
- run constrained operational tools
- limited local actions, with review or approval as appropriate

### Tier 4: High-trust
- use secrets
- affect live infrastructure
- send outbound communications
- perform destructive or irreversible actions

Tier 4 should be rare and tightly governed.

## Relationship Model

For every agent, define the following explicitly:

- Who can invoke it?
- Can it be used directly by the human, or only through the orchestrator?
- What authority tier does it have?
- What tools may it use?
- What memory may it access?
- Is it advisory only, or may it produce writes or actions?
- How are its outputs reviewed?
- When must it escalate to the orchestrator or the human?

This should be documented, not assumed.

## Memory Model

### Shared memory

Use shared memory for broad continuity.

Examples:
- a curated long-term memory file
- daily operational memory files

### Agent-specific memory

Create agent-specific memory only when repeated domain work justifies it.

Use agent-specific memory for:
- durable specialist heuristics
- ongoing domain projects
- repeated workflows worth preserving

Avoid creating isolated memory files for every stylistic persona.

## Recommended Filesystem Layout

A suggested structure:

```text
workspace/
  agents/
    orchestrator/
      README.md
      profile.md
      routing.md
    3d-printing/
      README.md
      profile.md
      context.md
      tools.md
      playbooks/
    homelab/
      README.md
      profile.md
      context.md
      tools.md
      playbooks/
    research/
      README.md
      profile.md
      context.md
  documentation/
  memory/
  skills/
```

For portable, self-contained specialists, a project-bundle layout is also recommended:

```text
workspace/
  AGENTS.md
  skills/
  projects/
    <specialist-project>/
      AGENT.md
      README.md
      architecture.md
      rules.md
      skills/
      scripts/
      data/
      output/
      config/
      memory/
```

Use this pattern when the specialist may later be moved, shared, published in sanitized form, or developed as a semi-independent system. Keep host-level governance at the root, and keep domain logic inside the project bundle.

This layout may evolve, but consistency matters more than perfection.

## Standard Agent File Roles

### `README.md`
- quick overview
- scope and purpose
- where to start

### `profile.md`
- identity or role
- core responsibilities
- collaboration style
- success criteria
- anti-goals or boundaries

### `context.md`
- domain knowledge
- assumptions
- current environment context
- recurring constraints

### `tools.md`
- domain-relevant commands, systems, locations, or tool notes

### `routing.md`
- primarily for orchestrator use
- delegation rules
- escalation rules
- coordination patterns

### `playbooks/`
- repeatable workflows
- troubleshooting guides
- standard operating procedures

### `memory.md` or domain memory file
- durable domain continuity if justified

## Routing and Delegation Guidance

The orchestrator should delegate when:
- a task falls clearly into a specialist domain
- the specialist has better context or playbooks
- isolation improves clarity or safety
- a separate persona meaningfully improves the work

The orchestrator should handle directly when:
- work is simple or general
- governance or trust judgment is central
- multiple domains need coordination
- the output must be integrated across systems or docs

## Review Model

Not all agent output should be treated equally.

Suggested review expectations:
- Tier 1 outputs: usually review by orchestrator or human before acting
- Tier 2 outputs: review before commit or external use
- Tier 3 outputs: review for scope and side effects
- Tier 4 outputs: human approval before execution unless explicitly pre-authorized

## Recommended Early Standardization

To support most future needs, standardize these early:

- agent folder and file conventions
- metadata expectations for every new agent
- permission tiers
- routing expectations
- memory-scope rules
- review and approval model

## Questions to Answer Before Creating a New Agent

Before adding an agent, answer:
- What problem does this agent solve that the orchestrator should not handle directly?
- Is this a domain specialist, a persona, or both?
- Should it be a lightweight local folder or a self-contained portable project bundle?
- What context does it need?
- What tools does it actually need?
- What authority tier should it have?
- What memory, if any, should it keep?
- What must remain governed by the root host rather than the specialist itself?
- How will its output be reviewed?
- What is the minimum file structure needed to govern it well?

## Recommended Next Steps

1. Decide on the first specialist agent to design formally.
2. Create a standard agent profile template.
3. Create a standard agent folder skeleton.
4. Define routing and review expectations for specialist agents.
5. Define a minimal memory-scope model for future agents.

If this framework remains stable, it should support most future agent use cases without significant restructuring.
