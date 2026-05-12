write_step "Configuring SSH and Git..."

ssh_dir="$HOME/.ssh"
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"

ssh_key="$ssh_dir/id_ed25519"
if [[ ! -f "$ssh_key" ]]; then
  ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$ssh_key" -N ""
  write_ok "SSH key generated"
  echo ""
  echo "Add this public key to GitHub:"
  cat "${ssh_key}.pub"
  echo ""
else
  write_skip "SSH key already exists"
  cat "${ssh_key}.pub"
fi

if [[ "$GIT_USER_NAME" == "Your Name" ]]; then
  write_warn "git user.name placeholder detected. Set --git-user-name to configure identity."
else
  set_git_config_if_needed user.name "$GIT_USER_NAME"
fi

if [[ "$USER_EMAIL" == "your-email@example.com" ]]; then
  write_warn "git user.email placeholder detected. Set --user-email to configure identity."
else
  set_git_config_if_needed user.email "$USER_EMAIL"
fi

set_git_config_if_needed core.editor nvim
set_git_config_if_needed core.pager delta
set_git_config_if_needed interactive.diffFilter "delta --color-only --features=interactive"
set_git_config_if_needed delta.navigate true
set_git_config_if_needed diff.external difft
set_git_config_if_needed diff.tool difftastic
set_git_config_if_needed difftool.difftastic.cmd 'difft "$LOCAL" "$REMOTE"'
set_git_config_if_needed difftool.prompt false
set_git_config_if_needed pager.difftool true
set_git_config_if_needed diff.algorithm histogram
set_git_config_if_needed merge.conflictstyle zdiff3
set_git_config_if_needed init.defaultBranch main
set_git_config_if_needed fetch.prune true
set_git_config_if_needed pull.rebase true
set_git_config_if_needed rebase.autoStash true
set_git_config_if_needed push.autoSetupRemote true
set_git_config_if_needed rerere.enabled true
set_git_config_if_needed alias.dft '-c diff.external=difft diff'
set_git_config_if_needed alias.ds '-c diff.external=difft show --ext-diff'
set_git_config_if_needed alias.dl '-c diff.external=difft log -p --ext-diff'
