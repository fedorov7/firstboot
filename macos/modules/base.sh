write_step "Installing base packages..."

base_formulas=(
  git
  gh
  ripgrep
  fd
  bat
  fzf
  jq
  yq
  eza
  duf
  tree
  wget
  gawk
  unzip
  htop
  gdu
  git-delta
  just
  hyperfine
  direnv
  shellcheck
  shfmt
  yamllint
  ansible-lint
  pre-commit
  rsync
  socat
  difftastic
  tmux
)

for formula in "${base_formulas[@]}"; do
  install_brew_formula "$formula"
done
