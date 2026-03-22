# Windows 11 PowerShell Provisioning

## Summary

Extend the firstboot project with PowerShell-based provisioning for Windows 11,
mirroring the existing Ansible roles for Arch Linux. Each Linux role maps to a
PowerShell module script. A single `bootstrap.ps1` entry point orchestrates
execution, supports selective module runs, and enforces idempotency.

The Windows provisioning is complementary to the Linux playbook. WSL2
configuration is handled by the Linux side (`cli_tools` role); the two systems
are independent and can be run in any order.

**Note on Claude CLI:** Linux installs via `curl install.sh`; Windows uses
`npm install -g @anthropic-ai/claude-code` since npm is the official
distribution channel for Windows.

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
│   ├── python.ps1             # uv + Python 3.12 + ruff
│   ├── rust.ps1               # rustup + stable toolchain + components
│   ├── cpp.ps1                # VS Build Tools check, cmake, ninja, llvm, meson
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
- `Install-WingetPackage <id> [-Name <display>]` — idempotent winget install (checks both exit code and output text, uses `--accept-source-agreements --disable-interactivity`)
- `Install-PSModule <name>` — idempotent `Install-Module` wrapper
- `Initialize-Fnm` — evaluates `fnm env` into the current session; called by bootstrap after nodejs.ps1 and by any module needing npm/npx

### Module Execution Order

bootstrap.ps1 runs modules sequentially. After `nodejs.ps1` completes,
`Initialize-Fnm` is called to make `npm`/`npx` available for downstream
modules (`codex.ps1`, `claude.ps1`). This mirrors the Linux pattern where
each Ansible task sources nvm inline.

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
| `eza-community.eza` | Modern ls with git status |
| `muesli.duf` | Disk usage (modern df) |
| `7zip.7zip` | Archive manager (no built-in tar/gz for all formats) |
| `voidtools.Everything` | Instant file search via NTFS index |
| `Microsoft.PowerToys` | FancyZones, File Locksmith, dev utilities |
| `Git.Git` | Git for Windows |
| `GitHub.cli` | GitHub CLI |

Note: `tree.com` is built into Windows; no winget package needed.

### shell.ps1

1. Install oh-my-posh: `winget install JanDeDobbeleer.OhMyPosh`
2. Deploy `files/oh-my-posh.json` to `$env:USERPROFILE\.config\oh-my-posh.json`
3. Install PowerShell modules:
   - `PSReadLine` (update to latest)
   - `posh-git`
   - `Terminal-Icons`
   - `PSFzf`
4. Install zoxide: `winget install ajeetdsouza.zoxide`
5. Deploy `files/profile.ps1` to `$PROFILE.CurrentUserCurrentHost` (with backup)

### ssh.ps1

1. Enable and start `ssh-agent` Windows service
2. Generate `~/.ssh/id_ed25519` if not present
3. Display public key
4. Configure git globally:
   - `user.name`, `user.email`
   - `core.editor = nvim`
   - `core.pager = delta`
   - `interactive.diffFilter = delta --color-only --features=interactive`
   - `delta.navigate = true`
   - `diff.external = difft`
   - `diff.tool = difftastic`
   - `difftool.difftastic.cmd = difft "$LOCAL" "$REMOTE"`
   - `difftool.prompt = false`
   - `diff.algorithm = histogram`
   - `merge.conflictstyle = zdiff3`
   - `init.defaultBranch = main`
   - `pull.rebase = true`
   - `push.autoSetupRemote = true`

### neovim.ps1

1. `winget install Neovim.Neovim`
2. Clone AstroNvim config to `$env:LOCALAPPDATA\nvim`
3. If directory exists and is a git repo, pull latest

### nodejs.ps1

1. `winget install Schniz.fnm`
2. Initialize fnm into current session (`Initialize-Fnm`)
3. `fnm install --lts` + `fnm default lts-latest`
4. fnm init in PowerShell profile is handled by shell.ps1

### python.ps1

1. `winget install astral-sh.uv`
2. `winget install astral-sh.ruff`
3. `uv python install 3.12`
4. `uv tool install pyright mypy black pytest`

### rust.ps1

1. `winget install Rustlang.Rustup`
2. `rustup default stable`
3. Install components: `rust-analyzer`, `clippy`, `rustfmt` (check `rustup component list --installed` first)
4. `cargo install sccache`

### cpp.ps1

1. Verify VS Build Tools via `vswhere.exe` — warn if not found (do not install)
2. `winget install Kitware.CMake`
3. `winget install Ninja-build.Ninja`
4. `winget install LLVM.LLVM` (clang, clang-format, clangd)
5. `winget install mesonbuild.meson`
6. `winget install Microsoft.WinDbg` (native code / crash dump debugging)
7. `winget install Microsoft.Sysinternals.Suite` (Process Monitor, Process Explorer, Handle, VMMap)
8. Clone vcpkg: `git clone https://github.com/microsoft/vcpkg.git` + bootstrap
9. Optional: cppcheck

### cli_tools.ps1

Winget packages:

| Package ID | Purpose | Linux equivalent |
|---|---|---|
| `dandavison.delta` | Git diff viewer | git-delta |
| `sharkdp.hyperfine` | Benchmarking | hyperfine |
| `Casey.Just` | Task runner | just |
| `Watchexec.Watchexec` | File watcher | entr |
| `XAMPPRocky.tokei` | Code stats | tokei |
| `JesseDuffield.lazygit` | Git TUI | lazygit |
| `bootandy.dust` | Visual disk usage | du |
| `Wilfred.difftastic` | Structural diff (syntax-aware) | difftastic |

### codex.ps1

1. Verify fnm/node available; call `Initialize-Fnm` if npm not in session
2. `npm install -g @openai/codex`
3. Create `$env:USERPROFILE\.codex\` directory structure
4. Write/merge MCP servers into `config.toml`:
   - context7, memory, fetch, sequential-thinking, github (conditional)
5. Install curated skills via the Codex skill installer script
   (`~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py`).
   Requires running `codex` once to bootstrap the directory structure.
   Curated skills: pdf, doc
6. Clone and symlink non-curated skills:
   - `obra/superpowers` → clone to `~/.codex/skills/superpowers`, symlink entries
   - `Jeffallan/claude-skills` → clone to `~/.codex/skills/claude-skills`, symlink entries

### claude.ps1

1. Verify fnm/node available; call `Initialize-Fnm` if npm not in session
2. `npm install -g @anthropic-ai/claude-code`
3. Deploy `roles/claude/files/settings.json` to `$env:USERPROFILE\.claude\settings.json`
4. Write/merge MCP servers into `$env:USERPROFILE\.claude.json`:
   - context7, memory, fetch, sequential-thinking, github (conditional)
5. Add plugin marketplaces:
   - claude-plugins-official, superpowers-dev, fullstack-dev-skills
6. Enable plugins:
   - `superpowers@claude-plugins-official`
   - `context-engineering-fundamentals@context-engineering-marketplace`
   - `agent-architecture@context-engineering-marketplace`
   - `agent-evaluation@context-engineering-marketplace`
   - `agent-development@context-engineering-marketplace`
   - `cognitive-architecture@context-engineering-marketplace`
   - `fullstack-dev-skills@fullstack-dev-skills`
   - `clangd-lsp@claude-plugins-official`
   - `pyright-lsp@claude-plugins-official`

## Idempotency Strategy

Every action is guarded:

| Check | Method |
|---|---|
| Winget package installed | `winget list --id <PackageId> --exact` — check both exit code and output contains the ID |
| Command available | `Get-Command <name> -ErrorAction SilentlyContinue` |
| File/directory exists | `Test-Path <path>` |
| PS module installed | `Get-Module -ListAvailable <name>` |
| Windows service state | `Get-Service <name>` |
| Git repo present | `Test-Path <path>\.git` |
| Rust components | `rustup component list --installed` before adding |
| Config key present | Parse existing file, check for key before writing |

## Scope Exclusions

- **WSL2 setup** — handled by the Linux Ansible playbook
- **Windows Terminal settings.json** — too personal, user configures manually
- **VS Build Tools installation** — pre-installed, only verified
- **Windows Defender / firewall rules** — out of scope
- **Windows Update** — out of scope
- **Scoop / Chocolatey** — not needed; all packages available via winget

## PowerShell Profile (files/profile.ps1)

All tool initializations are guarded with `Get-Command` checks so the profile
works even when only a subset of modules has been run.

```powershell
# oh-my-posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:USERPROFILE\.config\oh-my-posh.json" | Invoke-Expression
}

# PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Modules
if (Get-Module -ListAvailable posh-git) { Import-Module posh-git }
if (Get-Module -ListAvailable Terminal-Icons) { Import-Module Terminal-Icons }
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# fnm
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}

# Completions
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    rustup completions powershell | Out-String | Invoke-Expression
}
if (Get-Command uv -ErrorAction SilentlyContinue) {
    uv generate-shell-completion powershell | Out-String | Invoke-Expression
}
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh completion -s powershell | Out-String | Invoke-Expression
}
```
