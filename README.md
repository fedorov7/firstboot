# firstboot

Ansible playbook for automated provisioning of a fresh Arch Linux workstation (including WSL2). Derived from real shell history to capture the exact set of packages, tools, and dotfiles needed for a productive development environment.

## What gets installed

| Role | Description |
|------|-------------|
| **base** | System upgrade, `base-devel`, core CLI utilities, lint/format tools (`shellcheck`, `shfmt`, `yamllint`, `ansible-lint`), GitHub/dev productivity tools (`github-cli`, `git-delta`, `just`, `hyperfine`), and network diagnostics (`lsof`, `rsync`, `socat`, `tcpdump`) |
| **yay** | Builds and installs [yay](https://github.com/Jguer/yay) AUR helper from source |
| **zsh** | Installs zsh, [antidote](https://getantidote.github.io/) plugin manager, [Powerlevel10k](https://github.com/romkatv/powerlevel10k) prompt, sets zsh as default shell, deploys dotfiles (`.zshrc`, `.zsh_plugins.txt`, `.p10k.zsh`) |
| **ssh** | Generates an ed25519 SSH keypair, configures global git `user.name` and `user.email` |
| **neovim** | Installs Neovim and clones [AstroNvim](https://astronvim.com/) user config to `~/.config/nvim` |
| **nodejs** | Installs [nvm](https://github.com/nvm-sh/nvm) and Node.js LTS |
| **python** | Installs [uv](https://github.com/astral-sh/uv), Python 3.12 via `uv python install`, and Python QA/tooling (`ruff`, `pytest`, `mypy`, `pyright`, `black`, `pipx`) |
| **rust** | Installs `rustup` + `llvm`, sets stable as default toolchain |
| **cpp** | Installs C/C++ and systems toolchain: `cmake`, `ninja`, `meson`, `gcc`, `clang`, `clang-tools-extra`, `lldb`, `cppcheck`, `bear`, `bpftrace`, coverage tools |
| **cli_tools** | Installs `lua`, configures WSL `interop` settings when applicable |
| **codex** | Installs [OpenAI Codex CLI](https://github.com/openai/codex), configures MCP servers (context7, memory, fetch, sequential-thinking, optional github), and installs skills from curated + superpowers/claude-skills sources |
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

This will execute all roles sequentially. When the SSH key is freshly generated, its public key is printed to the console — add it to GitHub before roles that require git+ssh (neovim config clone).

## Running specific roles

Use `--tags` to run a subset of roles:

```bash
# Only set up zsh and dotfiles
ansible-playbook site.yml --ask-become-pass --tags zsh

# Only install the C++ toolchain
ansible-playbook site.yml --ask-become-pass --tags cpp
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
| `nvm_version` | `v0.39.7` | nvm installer version |
| `node_version` | `--lts` | Node.js version to install via nvm |

Override at runtime:

```bash
ansible-playbook site.yml --ask-become-pass -e "nvm_version=v0.40.1 node_version=22"
```

## Secret Scanning

Run a local secret scan before pushing:

```bash
gitleaks git --source . --config .gitleaks.toml --redact
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
├── ansible.cfg
├── inventory.yml
├── site.yml
├── group_vars/
│   └── all.yml
└── roles/
    ├── base/tasks/main.yml
    ├── yay/tasks/main.yml
    ├── zsh/
    │   ├── tasks/main.yml
    │   └── files/{zshrc,zsh_plugins.txt,p10k.zsh}
    ├── ssh/tasks/main.yml
    ├── neovim/tasks/main.yml
    ├── nodejs/tasks/main.yml
    ├── python/tasks/main.yml
    ├── rust/tasks/main.yml
    ├── cpp/tasks/main.yml
    ├── cli_tools/tasks/main.yml
    ├── codex/tasks/main.yml
    └── claude/
        ├── tasks/main.yml
        └── files/settings.json
```

## Idempotency

All tasks are idempotent — safe to re-run at any time. Package installs use `state: present`, key generation checks for existing keys, yay/nvm/claude installs use `creates` guards, and dotfile copies create backups before overwriting.

## License

MIT
