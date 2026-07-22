---
name: codex-agent-teamwork
description: Coordinate Codex subagents for software work. Use when a task is non-trivial, spans multiple files or domains, needs investigation plus implementation, involves debugging, code review, architecture planning, documentation research, or would benefit from parallel read-only exploration while preserving token and approval budgets.
---

# Codex Agent Teamwork

## Core Rule

Do not delegate simple tasks. Handle one-file edits, direct questions, tiny config changes, and obvious mechanical fixes in the main thread.

For non-trivial development, delegate read-heavy or independently verifiable work to specialized agents, then keep the main thread responsible for decisions, edits, integration, and final verification.

Use no more than three subagents by default. Spawn more only when the user explicitly asks or the work has clearly independent domains.

## Routing Matrix

Use `explorer-terra` for fast read-only repository exploration, log triage, large-file scanning, and locating relevant code paths.

Use `docs-researcher` for current API, SDK, framework, platform, or Codex behavior research. Prefer official docs and configured documentation MCP servers.

Use `tester-terra` for running focused build, lint, typecheck, and test commands, then summarizing failures. It may write normal build/test artifacts but must not edit source files.

Use `reviewer-deep` for final or risky review: correctness, regressions, security, edge cases, and missing tests.

Use `architect-deep` for ambiguous architecture, migration, cross-module design, or high-impact tradeoff analysis before implementation.

## Delegation Patterns

For medium implementation tasks, start one `explorer-terra` only when context is unclear. The main thread implements after reading the summary.

For debugging, spawn `explorer-terra` to map code and logs, and `tester-terra` to reproduce or characterize failures. Add `docs-researcher` only when external behavior or current tool docs matter.

For code review, spawn `reviewer-deep`; add `tester-terra` when test selection or failures are unclear. Ask for findings first, sorted by severity.

For architecture, spawn `architect-deep` and optionally `explorer-terra` for codebase constraints. Do not edit until the main thread selects the approach.

## Prompt Contract

Give each subagent a self-contained prompt with scope, files or commands to inspect, constraints, and required output. Tell agents to return concise evidence, not raw logs.

Keep subagents read-only unless their job is testing or an explicitly independent implementation. Avoid parallel source edits to the same files.

Wait for all spawned agents before making integration decisions. Verify important claims in the main thread before reporting completion.

## Budget Guardrails

Prefer `gpt-5.6-terra` agents for exploration, docs, and testing summaries. Use deep/high reasoning only for review, architecture, security, or ambiguous root-cause work.

Skip delegation when setup time, token cost, or approval overhead is likely higher than doing the work directly.
