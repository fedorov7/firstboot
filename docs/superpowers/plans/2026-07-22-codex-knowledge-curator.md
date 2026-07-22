# Codex Knowledge Curator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only `knowledge-curator` Codex agent that proposes durable knowledge capture after non-trivial work.

**Architecture:** Extend the existing managed Codex custom-agent provisioning on Windows, Linux, and macOS. Update the managed `codex-agent-teamwork` skill to route knowledge-capture work, and document the role in README.

**Tech Stack:** PowerShell provisioning, Ansible YAML role defaults/tasks, bash macOS provisioning, Markdown skill/docs, PowerShell static tests.

## Global Constraints

- `knowledge-curator` must be read-only.
- The curator suggests skill or documentation candidates but never creates them directly.
- Use lean/Terra model defaults unless the task explicitly requires deep review.
- Do not invoke the curator for simple one-file edits, direct answers, or mechanical formatting.
- Do not commit unless the user explicitly asks.

---

### Task 1: RED Tests

**Files:**
- Modify: `tests/powershell/test_codex_agent_teamwork.ps1`
- Modify: `tests/powershell/test_codex_profiles_agents.ps1`

**Interfaces:**
- Consumes: existing static provisioning tests.
- Produces: failing assertions for `knowledge-curator` defaults, instructions, read-only sandbox, skill routing, and README documentation.

- [ ] **Step 1: Add assertions for `knowledge-curator`**

Add expected strings to both tests before modifying production files.

- [ ] **Step 2: Run targeted tests**

Run:

```powershell
pwsh -NoProfile -File tests\powershell\test_codex_agent_teamwork.ps1
pwsh -NoProfile -File tests\powershell\test_codex_profiles_agents.ps1
```

Expected: at least one test fails because `knowledge-curator` is not yet provisioned or documented.

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
- Produces: managed `knowledge-curator.toml` on all platforms with read-only sandbox.

- [ ] **Step 1: Add the agent to defaults**

Append `knowledge-curator` to Windows, Linux, and macOS default custom-agent allowlists.

- [ ] **Step 2: Add agent definitions**

Use the lean/Terra model, medium reasoning, `sandbox_mode = "read-only"`, and instructions that require concise evidence-backed knowledge-capture candidates.

- [ ] **Step 3: Run targeted tests**

Run the two targeted PowerShell tests again.

Expected: tests pass after README and skill updates from Task 3.

### Task 3: Skill And Docs

**Files:**
- Modify: `codex/skills/codex-agent-teamwork/SKILL.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `knowledge-curator` custom agent.
- Produces: routing guidance and documentation for safe knowledge capture.

- [ ] **Step 1: Update the skill**

Add `knowledge-curator` to the routing matrix and add a `Knowledge Capture` section with use/skip rules and the required output shape.

- [ ] **Step 2: Update README**

Document the default agent set and explain that `knowledge-curator` proposes candidates but does not auto-write skills.

- [ ] **Step 3: Validate the skill**

Run:

```powershell
uv run --with pyyaml python C:\Users\Administrator\.codex\skills\.system\skill-creator\scripts\quick_validate.py codex\skills\codex-agent-teamwork
```

Expected: `Skill is valid!`

### Task 4: Apply And Verify

**Files:**
- Runtime target: `~\.codex\agents\knowledge-curator.toml`
- Runtime target: `~\.codex\skills\codex-agent-teamwork\SKILL.md`

**Interfaces:**
- Consumes: repository provisioning changes.
- Produces: current-machine Codex runtime configuration.

- [ ] **Step 1: Apply Windows module**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\windows\bootstrap.ps1 -Modules codex
```

Expected: `knowledge-curator` is installed or already current.

- [ ] **Step 2: Run final checks**

Run PowerShell tests, PowerShell parser checks, YAML validation, bash syntax checks, skill validation, and `git diff --check`.

Expected: all commands exit 0. Git may print CRLF warnings on Windows but no whitespace errors.
