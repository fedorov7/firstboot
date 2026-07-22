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

Use `improvement-researcher` for external improvement research: better tools, skills, MCP servers, configuration recipes, process upgrades, developer-experience tuning, or agent workflow practices. Require sources, repo fit, risk, and suggested next steps.

Use `tester-terra` for running focused build, lint, typecheck, and test commands, then summarizing failures. It may write normal build/test artifacts but must not edit source files.

Use `reviewer-deep` for final or risky review: correctness, regressions, security, edge cases, and missing tests.

Use `architect-deep` for ambiguous architecture, migration, cross-module design, or high-impact tradeoff analysis before implementation.

Use `knowledge-curator` near the end of non-trivial work when the session discovered a reusable command, debugging path, cross-platform provisioning fix, Codex permission rule, or workflow pattern that may be worth saving as a skill or repository guidance.

## Delegation Patterns

For medium implementation tasks, start one `explorer-terra` only when context is unclear. The main thread implements after reading the summary.

For debugging, spawn `explorer-terra` to map code and logs, and `tester-terra` to reproduce or characterize failures. Add `docs-researcher` only when external behavior or current tool docs matter.

For improvement research, spawn `improvement-researcher` only when the user asks to improve processes, tooling, skills, MCP, Codex configuration, or developer experience using current external information. Do not use it for direct API lookup; use `docs-researcher` instead.

For code review, spawn `reviewer-deep`; add `tester-terra` when test selection or failures are unclear. Ask for findings first, sorted by severity.

For architecture, spawn `architect-deep` and optionally `explorer-terra` for codebase constraints. Do not edit until the main thread selects the approach.

## Improvement Research

Use `improvement-researcher` as an opt-in or intent-triggered role, not as a default step. It is appropriate for questions like "what can we improve", "find new useful skills or MCP servers", "update our Codex workflow", or "research current best practices before provisioning changes".

Ask it to return ranked proposals in this shape:

```text
Finding: short title
Source: link or exact source name
Why It Matters: concrete benefit
Fit For This Repo: how it maps to current firstboot scripts, skills, agents, or docs
Risk Or Cost: security, maintenance, runtime, token, or compatibility concern
Suggested Next Step: adopt, test, document, defer, or reject
```

The researcher is advisory. The main thread filters proposals, verifies sources, and decides what to implement. After a change proves useful, use `knowledge-curator` to decide whether to preserve it as a skill or repository guidance.

## Knowledge Capture

Use `knowledge-curator` at most once per task, after the main fix or investigation is understood. Do not use it for simple one-file edits, direct answers, mechanical formatting, or one-off findings.

Ask it to return only evidence-backed candidates in this shape:

```text
Candidate: short title
Evidence: files, commands, errors, or artifacts that prove this was useful
Reuse Trigger: when future Codex sessions should remember this
Recommended Target: skill, AGENTS.md, README, or no action
Draft Guidance: 3-6 lines of reusable instruction
```

The curator is advisory. The main thread decides whether to write or update a skill, and must verify the proposed guidance before saving it.

## Prompt Contract

Give each subagent a self-contained prompt with scope, files or commands to inspect, constraints, and required output. Tell agents to return concise evidence, not raw logs.

Keep subagents read-only unless their job is testing or an explicitly independent implementation. Avoid parallel source edits to the same files.

Wait for all spawned agents before making integration decisions. Verify important claims in the main thread before reporting completion.

## Budget Guardrails

Prefer `gpt-5.6-terra` agents for exploration, docs, and testing summaries. Use deep/high reasoning only for review, architecture, security, or ambiguous root-cause work.

Skip delegation when setup time, token cost, or approval overhead is likely higher than doing the work directly.
