# Codex Improvement Researcher Design

## Goal

Add a managed Codex role that looks outside the repository for better tools, practices, skills, MCP servers, configuration recipes, and development workflow improvements. The role should expand project knowledge beyond the model's built-in memory while keeping implementation decisions explicit and reviewable.

## Non-Goals

The researcher must not edit files, install tools, change configuration, or create skills directly. It must not browse on every task, chase generic trend lists, or recommend changes without explaining fit, cost, and risk for this repository.

## Agent Role

Create a custom agent named `improvement-researcher`.

- `sandbox_mode = "read-only"`
- default model: lean/Terra profile
- reasoning effort: medium
- purpose: current external research for process, tooling, quality, and agent workflow improvements
- sources: official docs, primary project repositories, release notes, credible technical posts when primary sources are insufficient
- output: ranked, evidence-backed improvement proposals

The agent returns findings in this shape:

```text
Finding: short title
Source: link or exact source name
Why It Matters: concrete benefit
Fit For This Repo: how it maps to current firstboot scripts, skills, agents, or docs
Risk Or Cost: security, maintenance, runtime, token, or compatibility concern
Suggested Next Step: adopt, test, document, defer, or reject
```

## Relationship To Existing Agents

`docs-researcher` answers targeted documentation questions for known APIs, SDKs, platforms, and Codex behavior.

`improvement-researcher` starts from a quality/process goal and searches for new or better external approaches.

`knowledge-curator` preserves proven knowledge after the main task validates it. It may receive follow-up candidates from `improvement-researcher`, but it should not perform open-ended external research.

## Workflow

Update `codex-agent-teamwork` with an `Improvement Research` section. The main agent should consider `improvement-researcher` only when the user asks to improve tooling, update processes, find useful skills or MCP servers, tune Codex/agent workflows, improve Windows/Linux developer experience, or research modern practices before changing provisioning.

Do not invoke it for simple coding tasks, direct API lookups, normal bug fixes, or tasks where official documentation for a known tool is enough.

The main agent remains responsible for filtering proposals, choosing what to implement, and verifying any adopted change.

## Storage Policy

Store accepted and verified recurring workflows as repository-managed skills under `codex/skills/<name>/SKILL.md`.

Store always-on project behavior in `AGENTS.md`.

Store decision context in docs when it helps future maintainers but is not operational enough to be a skill.

Discard proposals that are speculative, source-poor, too broad, unsafe, or not clearly useful for this workstation-provisioning repository.

## Provisioning Changes

Add `improvement-researcher` to the managed custom agents on Windows, Linux, and macOS. Include it in the default `CodexCustomAgents` / `codex_custom_agents` / `CODEX_CUSTOM_AGENTS` allowlists.

Update tests to assert that:

- all three platforms provision `improvement-researcher`
- the agent is read-only
- the agent instruction includes source quality, fit, risk, and suggested next step fields
- `codex-agent-teamwork` documents when to use and when to skip improvement research
- README documents the role and its relationship to `docs-researcher` and `knowledge-curator`

## Safety And Budget Rules

The researcher should be opt-in or intent-triggered, not part of every task. External research costs tokens and may involve stale or low-quality sources, so the agent must cite sources and surface uncertainty. Any network-dependent recommendation must be verified before provisioning changes are committed.

## Acceptance Criteria

- `improvement-researcher` is provisioned consistently on Windows, Linux, and macOS.
- `codex-agent-teamwork` includes clear improvement-research routing.
- Documentation explains the role without encouraging broad web browsing on routine tasks.
- Existing PowerShell tests, syntax checks, YAML validation, bash syntax checks, and skill validation pass.
