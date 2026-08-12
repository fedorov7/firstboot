#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
expected_version="v0.40.4"

grep -Fq "nvm_version: \"${expected_version}\"" "$repo_root/group_vars/all.yml"
grep -Fq "NVM_VERSION=\"\${NVM_VERSION:-${expected_version}}\"" "$repo_root/macos/bootstrap.sh"
grep -Fq "nvm installer version (default: ${expected_version})." "$repo_root/macos/bootstrap.sh"
grep -Fq "| \`nvm_version\` | \`${expected_version}\` |" "$repo_root/README.md"
grep -A5 -- "- name: Install nvm" "$repo_root/roles/nodejs/tasks/main.yml" | grep -Fq 'set -o pipefail'
