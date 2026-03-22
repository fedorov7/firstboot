# Windows 11 PowerShell Provisioning

## Summary

Extend the firstboot project with PowerShell-based provisioning for Windows 11,
mirroring the existing Ansible roles for Arch Linux. Each Linux role maps to a
PowerShell module script. A single `bootstrap.ps1` entry point orchestrates
execution, supports selective module runs, and enforces idempotency.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Provisioning engine | Native PowerShell scripts | No WinRM chicken-and-egg; zero dependencies on firstboot |
| Package manager | winget | Built into Windows 11, no extra install |
| Node.js version manager | fnm | Cross-platform, Rust-based, fast, winget-installable |
| C++ toolchain | VS Build Tools (pre-installed) + CMake/Ninja/LLVM via winget | User already has VS Build Tools; script only verifies presence |
| Shell experience | oh-my-posh + PSReadLine + posh-git + Terminal-Icons + zoxide + PSFzf | Parity with zsh stack on Linux |
| Project layout | Flat — `windows/` beside existing Ansible files | Minimal disruption, no restructuring |

## Directory Structure

```
windows/
├── bootstrap.ps1              # entry point (like site.yml)
├── modules/
│   ├── base.ps1               # winget packages, system utilities
│   ├── shell.ps1              # oh-my-posh, PSReadLine, PS modules, profile
│   ├── ssh.ps1                # OpenSSH agent, ssh-keygen, git config
│   ├── neovim.ps1             # Neovim + AstroNvim config
│   ├── nodejs.ps1             # fnm + Node.js LTS
│   ├── python.ps1             # uv + Python 3.12
│   ├── rust.ps1               # rustup + stable toolchain + components
│   ├── cpp.ps1                # VS Build Tools check, cmake, ninja, llvm
│   ├── cli_tools.ps1          # delta, hyperfine, just, watchexec, tokei
│   ├── codex.ps1              # Codex CLI + MCP servers + skills
│   └── claude.ps1             # Claude CLI + settings + MCP + marketplaces
└── files/
    ├── profile.ps1            # PowerShell profile ($PROFILE)
    └── oh-my-posh.json        # oh-my-posh lean theme (p10k analog)
```

## bootstrap.ps1

### Requirements

- Must run in an **elevated** (Administrator) PowerShell session.
- PowerShell 7+ recommended (`pwsh`); Windows PowerShell 5.1 supported as fallback.

### Interface

```powershell
# Run all modules in order:
.\bootstrap.ps1

# Run specific modules:
.\bootstrap.ps1 -Modules shell,rust,claude

# Override config variables:
.\bootstrap.ps1 -UserEmail "user@example.com" -GitUserName "Name"
```

### Configuration Variables

Declared as parameters with defaults at the top of `bootstrap.ps1`:

| Variable | Default | Description |
|---|---|---|
| `$UserEmail` | `"your-email@example.com"` | Git and SSH key comment |
| `$GitUserName` | `"Your Name"` | Git user.name |
| `$NodeVersion` | `"lts-latest"` | fnm install target |
| `$AstroNvimRepo` | `"https://github.com/fedorov7/astronvim-config-v4.git"` | Neovim config repo |
| `$GithubToken` | `""` | Optional, for MCP github server |

### Helper Functions

Defined in `bootstrap.ps1`, available to all modules via dot-sourcing:

- `Write-Step <message>` — colored progress output
- `Test-CommandExists <name>` — `Get-Command` wrapper returning bool
- `Install-WingetPackage <id> [-Name <display>]` — idempotent winget install
- `Install-PSModule <name>` — idempotent `Install-Module` wrapper

## Module Specifications

### base.ps1

Winget packages:

| Package ID | Purpose |
|---|---|
| `BurntSushi.ripgrep.MSVC` | Fast grep |
| `sharkdp.fd` | Fast find |
| `sharkdp.bat` | cat with syntax highlighting |
| `junegunn.fzf` | Fuzzy finder |
| `jqlang.jq` | JSON processor |
| `MikeFarah.yq` | YAML processor |
| `gnuwin32.tree` | Directory tree |
| `dundee.gdu` | Disk usage analyzer |
| `muesli.duf` | Disk usage (modern df) |
| `aristocratos.btop4win` | System monitor |
| `Git.Git` | Git for Windows |
| `GitHub.cli` | GitHub CLI |

### shell.ps1

1. Install oh-my-posh: `winget install JanDeDobbeleer.OhMyPosh`
2. Deploy `files/oh-my-posh.json` to `$env:USERPROFILE\.config\oh-my-posh.json`
3. Install PowerShell modules:
   - `PSReadLine` (update to latest)
   - `posh-git`
   - `Terminal-Icons`
   - `PSFzf`
4. Install zoxide: `winget install ajeetdsouza.zoxide`
5. Deploy `files/profile.ps1` to `$PROFILE.CurrentUserAllHosts` (with backup)

### ssh.ps1

1. Enable and start `ssh-agent` Windows service
2. Generate `~/.ssh/id_ed25519` if not present
3. Display public key
4. Configure git globally:
   - `user.name`, `user.email`
   - `core.editor = nvim`
   - `core.pager = delta`
   - `interactive.diffFilter = delta --color-only --features=interactive`
   - `delta.navigate = true`, `delta.side-by-side = true`
   - `init.defaultBranch = main`
   - `pull.rebase = true`
   - `push.autoSetupRemote = true`

### neovim.ps1

1. `winget install Neovim.Neovim`
2. Clone AstroNvim config to `$env:LOCALAPPDATA\nvim`
3. If directory exists and is a git repo, pull latest

### nodejs.ps1

1. `winget install Schniz.fnm`
2. Add fnm init to PowerShell profile (handled by shell.ps1)
3. `fnm install --lts` + `fnm default lts-latest`

### python.ps1

1. `winget install astral-sh.uv`
2. `uv python install 3.12`

### rust.ps1

1. `winget install Rustlang.Rustup`
2. `rustup default stable`
3. Install components: `rust-analyzer`, `clippy`, `rustfmt`
4. `cargo install sccache`

### cpp.ps1

1. Verify VS Build Tools via `vswhere.exe` — warn if not found (do not install)
2. `winget install Kitware.CMake`
3. `winget install Ninja-build.Ninja`
4. `winget install LLVM.LLVM` (clang, clang-format, clangd)
5. Optional: cppcheck, meson

### cli_tools.ps1

Winget packages:

| Package ID | Purpose | Linux equivalent |
|---|---|---|
| `dandavison.delta` | Git diff viewer | git-delta |
| `sharkdp.hyperfine` | Benchmarking | hyperfine |
| `Casey.Just` | Task runner | just |
| `Watchexec.Watchexec` | File watcher | entr |
| `XAMPPRocky.tokei` | Code stats | tokei |
| `koalaman.shellcheck` | Shell linter | shellcheck |
| `mvdan.shfmt` | Shell formatter | shfmt |

### codex.ps1

1. Verify fnm/node available
2. `npm install -g @openai/codex`
3. Create `$env:USERPROFILE\.codex\` directory structure
4. Write/merge MCP servers into `config.toml`:
   - context7, memory, fetch, sequential-thinking, github (conditional)
5. Clone and symlink skills:
   - `openai/codex-skills` (curated: pdf, doc)
   - `anthropics/superpowers` → symlink
   - `Jeffallan/claude-skills` → symlink

### claude.ps1

1. Install Claude CLI: `npm install -g @anthropic-ai/claude-code`
2. Deploy `roles/claude/files/settings.json` to `$env:USERPROFILE\.claude\settings.json`
3. Write/merge MCP servers into `$env:USERPROFILE\.claude.json`:
   - context7, memory, fetch, sequential-thinking, github (conditional)
4. Add plugin marketplaces:
   - claude-plugins-official, superpowers-dev, fullstack-dev-skills
5. Enable plugins (same set as Linux)

## Idempotency Strategy

Every action is guarded:

| Check | Method |
|---|---|
| Winget package installed | `winget list --id <PackageId> --exact` exit code |
| Command available | `Get-Command <name> -ErrorAction SilentlyContinue` |
| File/directory exists | `Test-Path <path>` |
| PS module installed | `Get-Module -ListAvailable <name>` |
| Windows service state | `Get-Service <name>` |
| Git repo present | `Test-Path <path>\.git` |
| Config key present | Parse existing file, check for key before writing |

## Scope Exclusions

- **WSL2 setup** — handled by the Linux Ansible playbook
- **Windows Terminal settings.json** — too personal, user configures manually
- **VS Build Tools installation** — pre-installed, only verified
- **Windows Defender / firewall rules** — out of scope
- **Windows Update** — out of scope

## PowerShell Profile (files/profile.ps1)

```powershell
# oh-my-posh
oh-my-posh init pwsh --config "$env:USERPROFILE\.config\oh-my-posh.json" | Invoke-Expression

# PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Modules
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# fnm
fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

# Completions
rustup completions powershell | Out-String | Invoke-Expression
uv generate-shell-completion powershell | Out-String | Invoke-Expression
gh completion -s powershell | Out-String | Invoke-Expression
```
