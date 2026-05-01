# firstboot

Automated provisioning for **Arch Linux** (Ansible) and **Windows 11** (PowerShell). Derived from real shell history to capture the exact set of packages, tools, and dotfiles needed for systems programming (C++, Python, Rust) with AI agent support (Claude, Codex).

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
| **codex** | Installs [OpenAI Codex CLI](https://github.com/openai/codex), configures MCP servers from an allowlist (context7, OpenAI Developer Docs, memory, fetch, sequential-thinking, optional official GitHub/Serena), and installs an optimized allowlist of skills for app development, systems work, Python data/ML, review, and workflow discipline |
| **claude** | Installs [Claude CLI](https://claude.ai/code), deploys `settings.json` (permissions, model, plugins), configures MCP servers (context7, memory, fetch, sequential-thinking, optional github), and enables key plugin marketplaces/plugins |

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

This executes the default workstation roles. Heavy embedded, UEFI, and security scanner roles are opt-in; run them with their tags or enable their profile variables. When the SSH key is freshly generated, its public key is printed to the console - add it to GitHub before roles that require git+ssh (neovim config clone).

## Running specific roles

Use `--tags` to run a subset of roles:

```bash
# Only set up zsh and dotfiles
ansible-playbook site.yml --ask-become-pass --tags zsh

# Only install the C++ toolchain
ansible-playbook site.yml --ask-become-pass --tags cpp

# Opt in to embedded tooling
ansible-playbook site.yml --ask-become-pass --tags embedded
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
| `neovim_force_cleanup` | `false` | Remove Neovim config/data/state/cache before cloning, even when config is already a git repo |
| `neovim_cleanup_stale` | `true` | Remove stale non-git Neovim config/data/state/cache before cloning AstroNvim |
| `neovim_cleanup_paths` | Neovim XDG config/data/state/cache paths | Directories removed only when cleanup is explicitly forced or stale state is detected |
| `nvm_version` | `v0.39.7` | nvm installer version |
| `node_version` | `--lts` | Node.js version to install via nvm |
| `workstation_profile_embedded_enabled` | `false` | Include embedded tooling in an untagged full run |
| `workstation_profile_uefi_enabled` | `false` | Include UEFI tooling in an untagged full run |
| `workstation_profile_security_tools_enabled` | `false` | Include security scanners in an untagged full run |
| `embedded_probe_udev_rules_enabled` | `true` | Install common udev rules for ST-Link, J-Link, CMSIS-DAP, Black Magic, and ESP debug probes |
| `embedded_access_groups` | `uucp`, `lock` | Groups added to the user for serial device access |
| `embedded_probe_access_group` | `plugdev` | Group granted debug-probe USB access by udev rules |
| `codex_mcp_allowlist` | context/docs/memory defaults | MCP servers managed by the Codex role |
| `codex_mcp_prune_unmanaged` | `false` | Remove MCP servers outside `codex_mcp_allowlist` when you want an authoritative config |
| `codex_context7_remove_inline_api_key` | `true` | Recreate legacy context7 MCP entries that store an API key directly in `config.toml` |
| `codex_github_mcp_enabled` | `false` | Enables the official remote GitHub MCP server using `codex_github_token_env_var`, without storing a PAT in config |
| `codex_github_token_env_var` | `GITHUB_PERSONAL_ACCESS_TOKEN` | Environment variable Codex uses as the GitHub MCP bearer token |
| `codex_serena_enabled` | `false` | Enables Serena MCP via `uvx` for semantic code navigation/refactoring |
| `codex_remove_legacy_external_skill_sources` | `false` | Remove old role-managed `~/.codex/superpowers` and `~/.codex/claude-skills` source directories |
| `codex_curated_skills` | `pdf`, `doc` | Curated OpenAI skills installed directly into `~/.codex/skills` |
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
documentation, API design, DevOps, legacy analysis, security review, and
critical reasoning. Embedded-specific tooling remains opt-in. The Google
TimesFM forecasting skill is also opt-in because it is narrow and resource-aware
for time-series forecasting workflows. Re-running the role removes stale managed
entries from `~/.agents/skills/superpowers`,
`~/.agents/skills/claude-skills`, `~/.agents/skills/karpathy-skills`, and
legacy curated skill directories previously installed by this playbook. It only
removes MCP entries outside `codex_mcp_allowlist` when
`codex_mcp_prune_unmanaged=true`.

The Codex MCP configuration is also allowlist-driven. The default profile keeps
documentation and reasoning tools enabled while leaving broader access tools
disabled. To enable GitHub MCP, export a token in the configured environment
variable and run:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN=github_pat_xxx
ansible-playbook site.yml --ask-become-pass --tags codex -e codex_github_mcp_enabled=true
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

# Override config
.\bootstrap.ps1 -UserEmail "user@example.com" -GitUserName "Name"

# Enable TimesFM forecasting skill and runtime in the ML environment
.\bootstrap.ps1 -Modules python,ml,codex -MlTimesFmEnabled -CodexTimesFmSkillEnabled
```

### What gets installed (Windows)

| Module | Description |
|--------|-------------|
| **base** | Core CLI utilities via winget (ripgrep, fd, bat, fzf, jq, yq, eza, duf, 7-Zip, Everything, PowerToys, Git, GitHub CLI) |
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
| **claude** | Claude CLI + settings + MCP servers + marketplaces + plugins |

### Windows configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-UserEmail` | `your-email@example.com` | Git and SSH key comment |
| `-GitUserName` | `Your Name` | Global `git user.name` |
| `-NodeVersion` | `lts-latest` | fnm install target |
| `-AstroNvimRepo` | `https://github.com/fedorov7/astronvim-config-v4.git` | Neovim config repo |
| `-ForceNeovimCleanup` | off | Remove Neovim config/data/state/cache before cloning AstroNvim |
| `-GithubToken` | (empty) | Optional GitHub PAT copied into `-CodexGithubTokenEnvVar` for official GitHub MCP |
| `-CodexMcpAllowlist` | context/docs/memory defaults | Comma-separated Codex MCP allowlist |
| `-CodexMcpPruneUnmanaged` | off | Remove MCP servers outside the Windows Codex allowlist |
| `-CodexGithubMcpEnabled` | off | Enable official remote GitHub MCP without storing a PAT in Codex config |
| `-CodexGithubTokenEnvVar` | `GITHUB_PERSONAL_ACCESS_TOKEN` | Environment variable Codex uses as the GitHub MCP bearer token |
| `-CodexSerenaEnabled` | off | Enable Serena MCP via `uvx` |
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

**Linux:** Package installs use `state: present`, key generation checks for existing keys, yay/nvm/claude installs use `creates` guards, and dotfile copies create backups before overwriting. The Neovim role removes configured XDG paths only when cleanup is forced or a stale non-git config blocks the AstroNvim clone.

**Windows:** Each action is guarded (`winget list`, `Get-Command`, `Test-Path`, `Get-Module -ListAvailable`). Profile and settings deployments create timestamped backups.

## License

MIT
