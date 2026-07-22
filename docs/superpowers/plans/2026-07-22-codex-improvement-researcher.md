# Codex Improvement Researcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only `improvement-researcher` Codex agent that researches external process, tooling, skill, MCP, and workflow improvements.

**Architecture:** Extend the existing managed Codex custom-agent provisioning on Windows, Linux, and macOS. Update the managed `codex-agent-teamwork` skill to route improvement research separately from docs lookup and knowledge curation, and document the role in README.

**Tech Stack:** PowerShell provisioning, Ansible YAML role defaults/tasks, bash macOS provisioning, Markdown skill/docs, PowerShell static tests.

## Global Constraints

- `improvement-researcher` must be read-only.
- The researcher suggests improvements but must not edit files, install tools, change configuration, or create skills directly.
- The researcher should cite sources and explain fit, risk, and cost for this repository.
- The role is opt-in or intent-triggered, not part of every task.
- Do not commit unless the user explicitly asks.

---

### Task 1: RED Tests

**Files:**
- Modify: `tests/powershell/test_codex_agent_teamwork.ps1`
- Modify: `tests/powershell/test_codex_profiles_agents.ps1`

**Interfaces:**
- Consumes: existing static provisioning tests.
- Produces: failing assertions for `improvement-researcher` defaults, read-only sandbox, source quality, fit/risk output, skill routing, and README documentation.

- [ ] **Step 1: Add assertions for `improvement-researcher`**

Add expected strings to both tests before modifying provisioning or documentation.

- [ ] **Step 2: Run targeted tests**

Run:

```powershell
pwsh -NoProfile -File tests\powershell\test_codex_agent_teamwork.ps1
pwsh -NoProfile -File tests\powershell\test_codex_profiles_agents.ps1
```

Expected: at least one test fails because `improvement-researcher` is not yet provisioned or documented.

### Task 2: Provisioning

**Files:**
- Modify: `windows/bootstrap.ps1`
- Modify: `windows/modules/codex.ps1`
- Modify: `group_vars/all.yml`
- Modify: `roles/codex/tasks/main.yml`
- Modify: `macos/bootstrap.sh`
- Modify: `macos/modules/codex.sh`

**Interfaces:**
- Consumes: existing custom agent allowlists and agent content helpers.
- Produces: managed `improvement-researcher.toml` on all platforms with read-only sandbox.

- [ ] **Step 1: Add the agent to defaults**

Append `improvement-researcher` to Windows, Linux, and macOS default custom-agent allowlists.

- [ ] **Step 2: Add agent definitions**

Use the lean/Terra model, medium reasoning, `sandbox_mode = "read-only"`, and instructions that require sources, repo fit, risks, and suggested next steps.

- [ ] **Step 3: Run targeted tests**

Run the two targeted PowerShell tests again after Task 3.

Expected: both tests pass.

### Task 3: Skill And Docs

**Files:**
- Modify: `codex/skills/codex-agent-teamwork/SKILL.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `improvement-researcher` custom agent.
- Produces: routing guidance and documentation for safe external improvement research.

- [ ] **Step 1: Update the skill**

Add `improvement-researcher` to the routing matrix and add an `Improvement Research` section with use/skip rules and the required output shape.

- [ ] **Step 2: Update README**

Document the default agent set and explain how `improvement-researcher` differs from `docs-researcher` and `knowledge-curator`.

- [ ] **Step 3: Validate the skill**

Run:

```powershell
uv run --with pyyaml python C:\Users\Administrator\.codex\skills\.system\skill-creator\scripts\quick_validate.py codex\skills\codex-agent-teamwork
```

Expected: `Skill is valid!`

### Task 4: Apply And Verify

**Files:**
- Runtime target: `~\.codex\agents\improvement-researcher.toml`
- Runtime target: `~\.codex\skills\codex-agent-teamwork\SKILL.md`

**Interfaces:**
- Consumes: repository provisioning changes.
- Produces: current-machine Codex runtime configuration.

- [ ] **Step 1: Apply Windows module**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\windows\bootstrap.ps1 -Modules codex
```

Expected: `improvement-researcher` is installed or already current.

- [ ] **Step 2: Run final checks**

Run PowerShell tests, PowerShell parser checks, YAML validation, bash syntax checks, skill validation, and `git diff --check`.

Expected: all commands exit 0. Git may print CRLF warnings on Windows but no whitespace errors.
