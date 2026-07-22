# Codex Knowledge Curator Design

## Goal

Add a managed Codex role that captures reusable project knowledge after non-trivial work. The role should reduce repeated investigation by identifying proven commands, debugging paths, configuration fixes, and workflow decisions that are worth turning into skills or repository guidance.

## Non-Goals

The curator must not continuously watch every task, write source code, or auto-create skills without review. It should not preserve one-off observations, speculative ideas, raw logs, or decisions that are not likely to repeat.

## Agent Role

Create a custom agent named `knowledge-curator`.

- `sandbox_mode = "read-only"`
- default model: lean/Terra profile
- reasoning effort: medium
- purpose: inspect recent diffs, command results, failure modes, and successful fixes
- output: concise candidates for durable knowledge capture

The agent returns findings in this shape:

```text
Candidate: short title
Evidence: files, commands, errors, or artifacts that prove this was useful
Reuse Trigger: when future Codex sessions should remember this
Recommended Target: skill, AGENTS.md, README, or no action
Draft Guidance: 3-6 lines of reusable instruction
```

## Workflow

Update `codex-agent-teamwork` with a `Knowledge Capture` section. The main agent should consider `knowledge-curator` after tasks that include repeated failures, non-obvious tool setup, cross-platform provisioning behavior, Codex permission tuning, build/test command discovery, or debugging workflows that are likely to recur.

Do not invoke it for simple one-file edits, direct answers, mechanical formatting, or tasks where no new reusable process was discovered.

The main agent remains responsible for deciding whether to create or update a skill. Curator output is advisory, not authoritative.

## Storage Policy

Use repository-managed skills for stable repeatable workflows, such as `codex/skills/<name>/SKILL.md`.

Use `AGENTS.md` for project-level behavioral guidance that should always apply inside this repository.

Use documentation only for contextual decisions that are useful but not operational enough to be a skill.

Skip storage when the finding is one-off, unverified, too narrow, or would add noise.

## Provisioning Changes

Add `knowledge-curator` to the managed custom agents on Windows, Linux, and macOS. Include it in the default `CodexCustomAgents` / `codex_custom_agents` / `CODEX_CUSTOM_AGENTS` allowlists.

Update tests to assert that:

- all three platforms provision `knowledge-curator`
- the agent is read-only
- `codex-agent-teamwork` documents when to use and when to skip knowledge capture
- README documents the role and storage policy

## Safety And Budget Rules

The curator must not edit files, run destructive commands, or create skills directly. It should be spawned at most once per task and only near the end of meaningful work. For small tasks, the token cost is higher than the benefit, so the main agent should skip it.

## Acceptance Criteria

- `knowledge-curator` is provisioned consistently on Windows, Linux, and macOS.
- `codex-agent-teamwork` includes clear knowledge-capture routing.
- Documentation explains the role without encouraging noisy skill creation.
- Existing PowerShell tests, syntax checks, YAML validation, bash syntax checks, and skill validation pass.
