# firstboot

Automated provisioning for **Arch Linux** (Ansible), **macOS** (Bash + Homebrew), and **Windows 11** (PowerShell). Derived from real shell history to capture the exact set of packages, tools, and dotfiles needed for systems programming (C++, Python, Rust) with AI agent support (Claude, Codex).

## What gets installed

| Role | Description |
|------|-------------|
| **base** | System upgrade, `base-devel`, core CLI utilities, lint/format tools (`shellcheck`, `shfmt`, `yamllint`, `ansible-lint`), GitHub/dev productivity tools (`github-cli`, `git-delta`, `just`, `hyperfine`), and network diagnostics (`lsof`, `rsync`, `socat`, `tcpdump`) |
| **yay** | Builds and installs [yay](https://github.com/Jguer/yay) AUR helper from source |
| **zsh** | Installs zsh, [antidote](https://getantidote.github.io/) plugin manager, [Powerlevel10k](https://github.com/romkatv/powerlevel10k) prompt, sets zsh as default shell, deploys dotfiles (`.zshrc`, `.zsh_plugins.txt`, `.p10k.zsh`) |
| **ssh** | Generates an ed25519 SSH keypair, configures global git `user.name` and `user.email` |
| **neovim** | Installs Neovim, cleans stale non-git Neovim state when needed, and clones or updates [AstroNvim](https://astronvim.com/) user config to `~/.config/nvim` |
| **nodejs** | Installs [nvm](https://github.com/nvm-sh/nvm) and Node.js LTS |
| **python** | Installs [uv](https://github.com/astral-sh/uv), Python 3.12 via `uv python install`, and Python QA/tooling (`ruff`, `pytest`, `mypy`, `pyright`, `black`, `pipx`) |
| **rust** | Installs `rustup` + `llvm`, sets stable as default toolchain |
| **cpp** | Installs C/C++ and systems toolchain: `cmake`, `ninja`, `meson`, `gcc`, `clang`, `clang-tools-extra`, `lldb`, `cppcheck`, `bear`, `bpftrace`, coverage tools |
| **embedded** | Optional role for embedded host tooling (`dtc`, `dfu-util`, `openocd`, `probe-rs`, `stlink`, serial tools) and non-root debug-probe access |
| **uefi** | Optional role for UEFI/EDK2/QEMU tooling (`nasm`, `acpica`, QEMU emulators, `edk2-ovmf`, signing and firmware analysis utilities) |
| **security_tools** | Optional role for local security/compliance scanners (`gitleaks`, `trivy`, `osv-scanner`, `cargo-audit`, `cargo-deny`, `flawfinder`, `codespell`, `reuse`) |
| **cli_tools** | Installs `lua`, configures WSL `interop` settings when applicable |
| **codex** | Installs [OpenAI Codex CLI](https://github.com/openai/codex), configures MCP servers from an allowlist (context7, OpenAI Developer Docs, Microsoft Learn, memory, fetch, sequential-thinking, optional official GitHub/Serena/Playwright), and installs an optimized allowlist of skills for app development, systems work, Python data/ML, review, and workflow discipline |
| **claude** | Optional role that installs [Claude CLI](https://claude.ai/code), deploys `settings.json` (permissions, model, plugins), configures MCP servers (context7, memory, fetch, sequential-thinking, optional github), and enables key plugin marketplaces/plugins |

## Prerequisites

- A running Arch Linux system (bare metal or WSL2)
- `sudo` access
- Ansible installed:

```bash
sudo pacman -S ansible
```

## Quick start

Clone the repo and run:

```bash
git clone <repo-url> ~/firstboot && cd ~/firstboot
ansible-playbook site.yml --ask-become-pass
```

This executes the default workstation roles. Heavy embedded, UEFI, security scanner, and Claude roles are opt-in; run them with their tags or enable their profile variables. When the SSH key is freshly generated, its public key is printed to the console - add it to GitHub before roles that require git+ssh (neovim config clone).

## Running specific roles

Use `--tags` to run a subset of roles:

```bash
# Only set up zsh and dotfiles
ansible-playbook site.yml --ask-become-pass --tags zsh

# Only install the C++ toolchain
ansible-playbook site.yml --ask-become-pass --tags cpp

# Opt in to embedded tooling
ansible-playbook site.yml --ask-become-pass --tags embedded

# Opt in to Claude CLI and plugins
ansible-playbook site.yml --ask-become-pass --tags claude
```

To skip roles:

```bash
# Everything except rust and cpp
ansible-playbook site.yml --ask-become-pass --skip-tags rust,cpp
```

If Ansible exits with `ERROR: Ansible could not initialize the preferred locale: unsupported locale setting`, force a UTF-8 locale for the current shell:

```bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

## Targeting a remote host

Edit `inventory.yml` to add remote machines:

```yaml
all:
  hosts:
    workstation:
      ansible_host: 10.66.66.9
      ansible_user: alexander
```

Then run:

```bash
ansible-playbook site.yml --ask-become-pass --limit workstation
```

## Configuration

All tuneable variables live in `group_vars/all.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `user_email` | `your-email@example.com` | Used for SSH key comment and git config |
| `git_user_name` | `Your Name` | Global `git user.name` |
| `astronvim_repo` | `https://github.com/fedorov7/astronvim-config-v4.git` | Neovim config repository |
| `neovim_force_cleanup` | `true` | Remove Neovim config/data/state/cache before cloning, even when config is already a git repo |
| `neovim_cleanup_stale` | `true` | Remove stale non-git Neovim config/data/state/cache before cloning AstroNvim |
| `neovim_cleanup_paths` | Neovim XDG config/data/state/cache paths | Directories removed only when cleanup is explicitly forced or stale state is detected |
| `nvm_version` | `v0.39.7` | nvm installer version |
| `node_version` | `--lts` | Node.js version to install via nvm |
| `workstation_profile_embedded_enabled` | `false` | Include embedded tooling in an untagged full run |
| `workstation_profile_uefi_enabled` | `false` | Include UEFI tooling in an untagged full run |
| `workstation_profile_security_tools_enabled` | `false` | Include security scanners in an untagged full run |
| `workstation_profile_claude_enabled` | `false` | Include Claude CLI setup in an untagged full run |
| `embedded_probe_udev_rules_enabled` | `true` | Install common udev rules for ST-Link, J-Link, CMSIS-DAP, Black Magic, and ESP debug probes |
| `embedded_access_groups` | `uucp`, `lock` | Groups added to the user for serial device access |
| `embedded_probe_access_group` | `plugdev` | Group granted debug-probe USB access by udev rules |
| `codex_mcp_allowlist` | context/OpenAI/Microsoft docs/memory defaults | MCP servers managed by the Codex role |
| `codex_mcp_prune_unmanaged` | `false` | Remove MCP servers outside `codex_mcp_allowlist` when you want an authoritative config |
| `codex_context7_remove_inline_api_key` | `true` | Recreate legacy context7 MCP entries that store an API key directly in `config.toml` |
| `codex_sandbox_mode` | `workspace-write` | Allow Codex file/shell work inside the active workspace without full-system access |
| `codex_approval_policy` | `on-request` | Do not prompt for ordinary sandboxed workspace commands; ask before approved out-of-workspace operations |
| `codex_approvals_reviewer` | `user` | Send eligible approval prompts to the user instead of automatic review |
| `codex_check_for_update_on_startup` | `true` | Let Codex check for CLI updates on startup |
| `codex_model` | `gpt-5.6-sol` | Default Codex model for demanding local development work |
| `codex_model_reasoning_effort` | `high` | Strong default reasoning without using the highest-cost/limit-heavy effort by default |
| `codex_service_tier` | `default` | Preserve the account default service tier unless overridden |
| `codex_agents_max_threads` | `4` | Caps concurrent agent threads below Codex's higher default to reduce rate-limit and local-resource spikes |
| `codex_apps_default_tools_approval_mode` | `writes` | Allow read-only app tools while prompting for write-capable tools |
| `codex_update_enabled` | `false` | Reinstall/update the Codex CLI during provisioning when explicitly enabled |
| Codex trusted tool rules | git/rg/fd/bat/eza/delta/difft/difftastic/just/uv run | Allow common local workspace inspection and project commands without repeated prompts |
| Codex privileged prompt rules | git push/reset/clean, sudo/winget/brew/cargo install/uv tool/npm global/pip install/system settings | Keep destructive, remote, and system-changing commands available through explicit approval instead of broad shell trust |
| Windows Codex PowerShell read rules | Get-Content/Select-String/Get-ChildItem/Test-Path/etc. | Allow read-only workspace inspection and output formatting cmdlets without repeated prompts |
| `codex_apps_enabled` | `false` | Enables Codex built-in ChatGPT Apps MCP; disabled by default to avoid startup warnings on restricted networks |
| `codex_github_mcp_enabled` | `false` | Enables the official remote GitHub MCP server using `codex_github_token_env_var`, without storing a PAT in config |
| `codex_github_token_env_var` | `GITHUB_PERSONAL_ACCESS_TOKEN` | Environment variable Codex uses as the GitHub MCP bearer token |
| `codex_fetch_mcp_approval_mode` | `prompt` | Keep broad web fetch MCP interactive by default |
| `codex_microsoft_learn_mcp_approval_mode` | `writes` | Allow read-only Microsoft Learn MCP lookups while prompting for non-read-only tools |
| `codex_github_mcp_approval_mode` | `writes` | Let GitHub MCP reads run while prompting for write-capable tools |
| `codex_serena_mcp_approval_mode` | `writes` | Let Serena read/navigation tools run while prompting for write-capable tools |
| `codex_playwright_mcp_approval_mode` | `prompt` | Keep browser automation MCP tools interactive |
| `codex_serena_enabled` | `false` | Enables Serena MCP via `uvx` for semantic code navigation/refactoring |
| `codex_playwright_mcp_enabled` | `false` | Enables Playwright MCP browser automation via `npx @playwright/mcp` |
| `codex_remove_legacy_external_skill_sources` | `false` | Remove old role-managed `~/.codex/superpowers` and `~/.codex/claude-skills` source directories |
| `codex_curated_skills` | CLI/Jupyter/PDF/Playwright/security/WinUI defaults | Curated OpenAI skills installed directly into `~/.codex/skills` |
| `codex_superpowers_skills` | workflow discipline allowlist | Superpowers skills symlinked into `~/.agents/skills/superpowers` |
| `codex_karpathy_skills` | `karpathy-guidelines` | Karpathy-inspired behavioral guidelines symlinked into `~/.agents/skills/karpathy-skills` |
| `codex_claude_skills` | systems + workflow allowlist | Claude/fullstack-dev skills symlinked into `~/.agents/skills/claude-skills` |

Override at runtime:

```bash
ansible-playbook site.yml --ask-become-pass -e "nvm_version=v0.40.1 node_version=22"
```

The Codex role keeps skills allowlist-driven to avoid accidental growth from
large skill packs. The default Windows profile targets C++/Rust/Lua/Python
application development and Python data/ML work: code review, debugging,
testing, C++/Rust/Python specialists, pandas, ML pipelines, fine-tuning,
SQL/database tuning, MCP development, documentation, API design, DevOps, legacy
analysis, security review, and critical reasoning. Curated OpenAI skills add
CLI creation, Jupyter notebooks, Playwright CLI workflows, security best
practices, WinUI app work, and PDF handling. Embedded-specific tooling remains
opt-in. The Google
TimesFM forecasting skill is also opt-in because it is narrow and resource-aware
for time-series forecasting workflows. Re-running the role removes stale managed
entries from `~/.agents/skills/superpowers`,
`~/.agents/skills/claude-skills`, `~/.agents/skills/karpathy-skills`, and
legacy curated skill directories previously installed by this playbook. It
removes MCP entries outside `codex_mcp_allowlist` when
`codex_mcp_prune_unmanaged=true`.

On Windows, Codex rules allow direct PowerShell read/output cmdlets. Broad shell
wrappers such as `pwsh` and `wsl bash -lc` are intentionally not trusted rules.
System-changing commands use explicit `prompt` rules, so package installs,
registry/service changes, WSL updates, and destructive or remote Git operations
remain possible but require confirmation.

The Codex MCP configuration is also allowlist-driven. The default profile keeps
documentation and reasoning tools enabled while leaving broader access tools
disabled. Microsoft Learn MCP is included by default for Windows, PowerShell,
WinUI, .NET, and Microsoft C++ documentation lookups. The built-in ChatGPT Apps
MCP is disabled by default because it starts a remote `chatgpt.com` handshake on
Codex startup. To enable GitHub MCP, export a token in the configured
environment variable and run:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN=github_pat_xxx
ansible-playbook site.yml --ask-become-pass --tags codex -e codex_github_mcp_enabled=true
```

Playwright MCP is opt-in because browser automation has heavier startup and
state behavior than the Playwright curated skill:

```bash
ansible-playbook site.yml --ask-become-pass --tags codex -e codex_playwright_mcp_enabled=true
```

## Secret Scanning

Run a local secret scan before pushing:

```bash
gitleaks git --redact .
trivy fs .
osv-scanner -r .
```

CI runs the same check on `push` (main) and `pull_request` via GitHub Actions.

## Customizing dotfiles

Zsh dotfiles are stored in `roles/zsh/files/`:

```
roles/zsh/files/
├── zshrc              # Main zsh config (antidote, p10k, nvm, rust completions)
├── zsh_plugins.txt    # Antidote plugin list
└── p10k.zsh           # Powerlevel10k theme config
```

Edit these files directly, then re-run the zsh role. Existing dotfiles are backed up automatically before overwriting.

## Project structure

```
firstboot/
|-- ansible.cfg              # Ansible config (Linux)
|-- inventory.yml            # Ansible inventory (Linux)
|-- site.yml                 # Ansible playbook entry point (Linux)
|-- group_vars/
|   `-- all.yml
|-- roles/                   # Ansible roles (Linux)
|   |-- base, yay, zsh, ssh, neovim, nodejs,
|   |-- python, rust, cpp, embedded, uefi,
|   |-- security_tools, cli_tools, codex, claude
|   `-- ...
|-- macos/                   # Bash provisioning (macOS)
|   |-- bootstrap.sh         # Entry point
|   |-- modules/
|   |   |-- base, shell, ssh, neovim, nodejs,
|   |   |-- python, rust, cpp, lua, ml, embedded, uefi,
|   |   |-- security_tools, cli_tools, codex, claude
|   |   `-- ...
|   `-- files/
|       `-- zshrc            # macOS shell profile template
`-- windows/                 # PowerShell provisioning (Windows 11)
    |-- bootstrap.ps1        # Entry point
    |-- modules/
    |   |-- base, shell, ssh, neovim, nodejs,
    |   |-- python, rust, cpp, lua, ml, embedded, uefi,
    |   |-- security_tools, cli_tools, codex, claude
    |   `-- ...
    `-- files/
        |-- profile.ps1      # PowerShell profile
        `-- oh-my-posh.json  # Prompt theme
```

## macOS quick start

Requires **macOS**. Homebrew is installed automatically if missing.

```bash
git clone <repo-url> ~/firstboot && cd ~/firstboot/macos
chmod +x bootstrap.sh
./bootstrap.sh
```

By default, the bootstrap runs:
`base,dev_settings,shell,ssh,neovim,nodejs,python,rust,cpp,lua,ml,cli_tools,codex`.
Optional modules are: `dev_drive`, `wsl`, `sudo`, `claude`.

### Running specific modules

```bash
# Core shell + language setup only
./bootstrap.sh --modules shell,nodejs,python,rust

# Enable optional ML and TimesFM integrations
./bootstrap.sh --modules python,ml,codex --ml-timesfm-enabled --codex-timesfm-skill-enabled

# Opt in to Claude CLI and plugins
./bootstrap.sh --modules claude
```

### What gets installed (macOS)

| Module | Description |
|--------|-------------|
| **base** | Core CLI and QA tooling via Homebrew (`rg`, `fd`, `jq`, `yq`, `git-delta`, `just`, `hyperfine`, `shellcheck`, `shfmt`, `ansible-lint`) |
| **shell** | zsh dotfiles deployment (`.zshrc`, `.zsh_plugins.txt`, `.p10k.zsh`), antidote plugin manager, zoxide |
| **ssh** | ed25519 key generation + opinionated global git defaults (delta + difftastic workflow) |
| **neovim** | Neovim install and AstroNvim clone/update with optional cleanup |
| **nodejs** | nvm + Node.js (`lts/*`) |
| **python** | uv + ruff + Python 3.12 + dev tools (`pyright`, `mypy`, `black`, `pytest`, `tox`, `nox`) |
| **rust** | rustup stable + components + cargo app-dev tools (`sccache`, `cargo-edit`, `cargo-watch`, `nextest`, `bacon`, `taplo`) |
| **cpp** | CMake, Ninja, LLVM, Meson, Cppcheck, Doxygen, Graphviz, ccache, bear, coverage tooling |
| **lua** | Optional Lua/LuaJIT/Lua LSP + StyLua |
| **ml** | Optional reusable `uv` ML environment (`~/.virtualenvs/firstboot-ml`) + Jupyter kernel + optional TimesFM runtime |
| **embedded** | Optional OpenOCD/probe-rs host tooling |
| **uefi** | Optional NASM/QEMU/firmware tooling |
| **security_tools** | Optional gitleaks/trivy/osv-scanner + cargo and uv security/compliance tools |
| **cli_tools** | delta, hyperfine, just, tokei, lazygit, dust, difftastic, watchexec |
| **codex** | Codex CLI + allowlist-managed MCP servers + allowlist-managed skill namespaces |
| **claude** | Optional Claude CLI + settings + MCP + plugin marketplaces/plugins |

### macOS configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--user-email` | detected from `git config --global user.email` | SSH key comment and git identity |
| `--git-user-name` | detected from `git config --global user.name` | Global `git user.name` |
| `--astronvim-repo` | detected from `~/.config/nvim` origin | Neovim config repo |
| `--force-neovim-cleanup` | on | Remove Neovim config/data/state/cache before clone/update |
| `--preserve-neovim-state` | off | Preserve existing Neovim config/data/state/cache unless stale non-git config blocks cloning |
| `--modules` | core module set | Comma-separated module selection |
| `--codex-mcp-allowlist` | context/OpenAI/Microsoft docs/memory defaults | Comma-separated Codex MCP allowlist |
| `--codex-mcp-prune-unmanaged` | off | Remove Codex MCP servers outside the allowlist |
| `--codex-github-mcp-enabled` | off | Enable official GitHub MCP in Codex |
| `--codex-playwright-mcp-enabled` | off | Enable Playwright MCP browser automation |
| `--codex-sandbox-mode` | `workspace-write` | Allow Codex workspace file/shell operations without full-system access |
| `--codex-approval-policy` | `on-request` | Do not prompt for ordinary sandboxed workspace commands; allow explicit escalation prompts |
| `--codex-model` | `gpt-5.6-sol` | Default Codex model for demanding local development |
| `--codex-model-reasoning-effort` | `high` | Strong reasoning default without using max/ultra by default |
| `--codex-service-tier` | `default` | Preserve account default service tier unless overridden |
| `--codex-agents-max-threads` | `4` | Limit concurrent Codex agent threads to reduce resource/rate-limit spikes |
| `--codex-apps-default-tools-approval-mode` | `writes` | Allow read-only app tools while prompting for writes |
| `--codex-microsoft-learn-mcp-approval-mode` | `writes` | Allow read-only Microsoft Learn MCP lookups while prompting for non-read-only tools |
| `--codex-playwright-mcp-approval-mode` | `prompt` | Keep browser automation MCP tools interactive |
| `--ml-python-version` | `3.12` | Python version for reusable ML environment |
| `--ml-environment-path` | `~/.virtualenvs/firstboot-ml` | Path for reusable ML venv |
| `--ml-timesfm-enabled` | off | Install TimesFM runtime in ML environment |
| `--ml-timesfm-backend` | `torch-default` | TimesFM backend: `torch-default`, `torch-cpu`, `flax` |

## Windows 11 quick start

Requires **PowerShell 7+** and **Administrator** privileges.

```powershell
git clone <repo-url> ~\firstboot; cd ~\firstboot\windows
.\bootstrap.ps1
```

### Running specific modules

```powershell
# Only set up shell and Rust
.\bootstrap.ps1 -Modules shell,rust

# Opt in to Claude CLI and plugins
.\bootstrap.ps1 -Modules claude

# Override config
.\bootstrap.ps1 -UserEmail "user@example.com" -GitUserName "Name"

# Enable TimesFM forecasting skill and runtime in the ML environment
.\bootstrap.ps1 -Modules python,ml,codex -MlTimesFmEnabled -CodexTimesFmSkillEnabled

# Tune WSL2 global resource settings without installing a distribution
.\bootstrap.ps1 -Modules wsl -WslConfigEnabled -WslMemory 16GB -WslProcessors 8 -WslSwap 8GB -WslSparseVhdEnabled
```

### What gets installed (Windows)

| Module | Description |
|--------|-------------|
| **base** | Core CLI utilities via winget (ripgrep, fd, bat, fzf, jq, yq, eza, duf, 7-Zip, Everything, PowerToys, Git, GitHub CLI) |
| **dev_settings** | Windows developer defaults: long paths, Explorer file extension/hidden-file visibility, optional Developer Mode |
| **dev_drive** | Optional Dev Drive inspection and trust workflow via `fsutil devdrv`; never creates or formats drives |
| **wsl** | Optional WSL inspection, install workflow, and guarded `.wslconfig` tuning |
| **sudo** | Optional Sudo for Windows configuration; defaults to safer `forceNewWindow` mode |
| **shell** | oh-my-posh + PSReadLine + posh-git + Terminal-Icons + zoxide + PSFzf, PowerShell profile, and a non-destructive Windows Terminal font patch (`CaskaydiaCove Nerd Font Mono`) |
| **ssh** | OpenSSH agent, ed25519 key, git config with delta and difftastic |
| **neovim** | Neovim + AstroNvim config |
| **nodejs** | fnm + Node.js LTS |
| **python** | uv + ruff + Python 3.12 + dev tools (pyright, mypy, black, pytest, pre-commit, tox, nox, IPython) |
| **rust** | rustup + stable toolchain + components + app-dev cargo tools (sccache, cargo-edit, cargo-watch, nextest, bacon, Taplo) |
| **cpp** | VS Build Tools check, CMake, Ninja, LLVM, meson, Cppcheck, Doxygen, Graphviz, Ccache, WinDbg, Sysinternals, vcpkg |
| **lua** | Lua, LuaJIT, Lua Language Server, and StyLua formatter |
| **ml** | Reusable `uv` Python environment for data/ML packages, JupyterLab, a registered `firstboot-ml` kernel, and optional TimesFM runtime |
| **embedded** | Optional module for OpenOCD xPack and probe-rs tooling |
| **uefi** | Optional module for NASM, QEMU, LLVM tools, and binwalk |
| **security_tools** | Optional module for gitleaks, trivy, osv-scanner, cargo-audit, cargo-deny, flawfinder, codespell, and reuse |
| **cli_tools** | delta, hyperfine, just, watchexec, tokei, lazygit, dust, difftastic |
| **codex** | Codex CLI installed in the configured fnm Node.js, allowlist-managed MCP servers, and allowlist-managed skills |
| **claude** | Optional Claude CLI + settings + MCP servers + marketplaces + plugins |

### Windows configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-UserEmail` | `your-email@example.com` | Git and SSH key comment |
| `-GitUserName` | `Your Name` | Global `git user.name` |
| `-NodeVersion` | `lts-latest` | fnm install target |
| `-AstroNvimRepo` | `https://github.com/fedorov7/astronvim-config-v4.git` | Neovim config repo |
| `-ForceNeovimCleanup` | `$true` | Remove Neovim config/data/state/cache before cloning AstroNvim |
| `-PreserveNeovimState` | off | Preserve existing Neovim config/data/state/cache unless stale non-git config blocks cloning |
| `-WindowsDeveloperModeEnabled` | off | Enable Windows Developer Mode registry settings; long paths and Explorer developer defaults are always configured by `dev_settings` |
| `-DevDrivePath` | (empty) | Optional Dev Drive volume path to query or trust, for example `D:` |
| `-DevDriveTrustEnabled` | off | Trust the selected Dev Drive without force-dismounting it; requires `-DevDrivePath` |
| `-WslInstallEnabled` | off | Install WSL with the selected distribution; otherwise the `wsl` module only inspects status |
| `-WslDistribution` | `Ubuntu` | Distribution passed to `wsl --install --distribution` |
| `-WslConfigEnabled` | off | Manage `%UserProfile%\.wslconfig`; existing files are backed up before edits |
| `-WslMemory` | (empty) | Optional WSL2 memory limit, for example `16GB` |
| `-WslProcessors` | `0` | Optional WSL2 processor count; `0` keeps the WSL default |
| `-WslSwap` | (empty) | Optional WSL2 swap size, for example `8GB` or `0` |
| `-WslNetworkingMode` | (empty) | Optional WSL2 networking mode: `none`, `nat`, `mirrored`, or `virtioproxy` |
| `-WslAutoMemoryReclaim` | `gradual` | Experimental WSL memory reclaim value used when `-WslConfigEnabled` is passed |
| `-WslSparseVhdEnabled` | off | Enable sparse VHD for newly created WSL distributions when `-WslConfigEnabled` is passed |
| `-WindowsSudoEnabled` | off | Enable Sudo for Windows when the `sudo` module is selected |
| `-WindowsSudoMode` | `forceNewWindow` | Sudo mode: `forceNewWindow`, `disableInput`, or `normal` |
| `-GithubToken` | (empty) | Optional GitHub PAT copied into `-CodexGithubTokenEnvVar` for official GitHub MCP |
| `-CodexMcpAllowlist` | context/OpenAI/Microsoft docs/memory defaults | Comma-separated Codex MCP allowlist |
| `-CodexMcpPruneUnmanaged` | off | Remove MCP servers outside the Windows Codex allowlist |
| `-CodexGithubMcpEnabled` | off | Enable official remote GitHub MCP without storing a PAT in Codex config |
| `-CodexGithubTokenEnvVar` | `GITHUB_PERSONAL_ACCESS_TOKEN` | Environment variable Codex uses as the GitHub MCP bearer token |
| `-CodexSerenaEnabled` | off | Enable Serena MCP via `uvx` |
| `-CodexPlaywrightMcpEnabled` | off | Enable Playwright MCP browser automation via `npx @playwright/mcp` |
| `-CodexSandboxMode` | `workspace-write` | Allow Codex workspace file/shell operations without full-system access |
| `-CodexApprovalPolicy` | `on-request` | Do not prompt for ordinary sandboxed workspace commands; allow explicit escalation prompts |
| `-CodexApprovalsReviewer` | `user` | Send eligible approval prompts to the user |
| `-CodexWindowsSandbox` | `elevated` | Use the stronger native Windows Codex sandbox mode |
| `-CodexWindowsSandboxPrivateDesktop` | `$true` | Keep native Windows sandboxed processes on a private desktop |
| `-CodexCheckForUpdateOnStartup` | `$true` | Let Codex check for CLI updates on startup |
| `-CodexModel` | `gpt-5.6-sol` | Default Codex model for demanding local development |
| `-CodexModelReasoningEffort` | `high` | Strong reasoning default without using max/ultra by default |
| `-CodexServiceTier` | `default` | Preserve account default service tier unless overridden |
| `-CodexAgentsMaxThreads` | `4` | Limit concurrent Codex agent threads to reduce resource/rate-limit spikes |
| `-CodexAppsDefaultToolsApprovalMode` | `writes` | Allow read-only app tools while prompting for writes |
| `-CodexFetchMcpApprovalMode` | `prompt` | Keep broad fetch MCP tools interactive |
| `-CodexMicrosoftLearnMcpApprovalMode` | `writes` | Allow read-only Microsoft Learn MCP lookups while prompting for non-read-only tools |
| `-CodexGithubMcpApprovalMode` | `writes` | Let GitHub MCP reads run while prompting for writes |
| `-CodexSerenaMcpApprovalMode` | `writes` | Let Serena read/navigation tools run while prompting for writes |
| `-CodexPlaywrightMcpApprovalMode` | `prompt` | Keep browser automation MCP tools interactive |
| `-CodexUpdateEnabled` | off | Update the global Codex CLI package during the Codex module run |
| `-CodexTimesFmSkillEnabled` | off | Enable Google Research TimesFM forecasting skill for Codex |
| `-CodexTimesFmSkillRepo` | `https://github.com/google-research/timesfm.git` | Source repo for the TimesFM skill |
| `-CodexTimesFmSkillPath` | `timesfm-forecasting` | Skill directory inside the TimesFM repo |
| `-MlPythonVersion` | `3.12` | Python version used for the ML virtual environment |
| `-MlEnvironmentPath` | `~\.virtualenvs\firstboot-ml` | Reusable ML virtual environment path |
| `-MlPythonPackages` | NumPy/pandas/sklearn/Jupyter defaults | Comma-separated ML package allowlist installed with `uv pip` |
| `-MlTimesFmEnabled` | off | Install TimesFM runtime into the ML virtual environment |
| `-MlTimesFmBackend` | `torch-cpu` | TimesFM backend: `torch-cpu`, `torch-cuda121`, `torch-default`, or `flax` |

## Idempotency

The playbook is designed to be safe to re-run at any time, with role-specific
exceptions documented below.

**Linux:** Package installs use `state: present`, key generation checks for existing keys, yay/nvm/claude installs use `creates` guards, and dotfile copies create backups before overwriting. The Neovim role removes configured XDG paths by default before cloning AstroNvim.

**macOS:** Homebrew installs are guarded with `brew list`, ssh/git configuration only updates when values differ, and dotfile/settings deployments create timestamped backups before overwriting. Neovim config/data/state/cache cleanup runs by default unless `--preserve-neovim-state` is passed.

**Windows:** Each action is guarded (`winget list`, `Get-Command`, `Test-Path`, `Get-Module -ListAvailable`). Profile and settings deployments create timestamped backups. Neovim config/data/state/cache cleanup runs by default unless `-PreserveNeovimState` is passed.

## License

MIT
