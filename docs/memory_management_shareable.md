# Memory Management (Shareable Reference)

<!-- PUBLIC_SHARE: approved-for-public-repo -->

This document describes how memory can be used and maintained in an OpenClaw workspace.

## Memory Layers

### Daily memory
Daily files can live in `memory/YYYY-MM-DD.md`.

Use daily memory for:
- recent decisions
- active work context
- follow-ups
- temporary notes
- lessons from current work
- items that may deserve later promotion to long-term memory

Daily memory should be practical and concise. Prefer summaries over raw transcripts.

### Long-term memory
Long-term memory can live in `MEMORY.md`.

Use long-term memory for:
- durable preferences
- trusted-channel and security posture
- stable environment information
- important long-term decisions
- recurring workflows worth preserving

Long-term memory should stay curated, compact, and high value.

## What Not to Store

Avoid storing the following unless there is a compelling reason:
- secrets or secret values
- raw tokens, API keys, recovery codes, or cookies
- large logs or copied transcripts
- excessive third-party personal details
- stale or superseded operational facts

## Best Practices

- Prefer summaries over raw capture
- Store decisions and lessons, not just chatter
- Keep daily memory separate from curated long-term memory
- Move behavioral rules to `AGENTS.md` when they become standing directives
- Move environment-specific operational notes to `TOOLS.md` when appropriate
- Prune long-term memory regularly

## Suggested Workflow

1. Write short notes to the current daily memory file as important things happen.
2. When a preference, decision, or workflow seems durable, add it to a section like "Notes Worth Promoting to MEMORY.md".
3. Every few days, review recent daily memory files.
4. Promote only stable, useful, non-sensitive items into `MEMORY.md`.
5. Rewrite or remove stale items from `MEMORY.md` rather than letting it grow indefinitely.

## Promotion Heuristic

Promote something to `MEMORY.md` if it is:
- likely to matter again
- stable over time
- useful for future continuity
- safe enough to preserve long-term

Otherwise, keep it in daily memory or let it expire.

## Maintenance Cadence

- Daily: add only important notes
- Every few days: review recent daily files
- Weekly or biweekly: prune and tighten `MEMORY.md`
- After major policy or workflow changes: update `MEMORY.md`, `AGENTS.md`, or `TOOLS.md` as appropriate
