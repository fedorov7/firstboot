# shellcheck shell=bash

codex_config_validate_file() {
  local candidate_path="$1"
  python3 - "$candidate_path" <<'PY'
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
tomllib.loads(path.read_text(encoding="utf-8"))
PY
}

codex_config_install_candidate() {
  local candidate_path="$1"
  local target_path="$2"

  codex_config_validate_file "$candidate_path" || return 1
  cp "$candidate_path" "$target_path"
}

codex_config_validate_runtime() {
  codex mcp list >/dev/null 2>&1
}
