# shellcheck shell=bash

replace_managed_block() {
  local input_path="$1"
  local begin="$2"
  local end="$3"
  local block_path="$4"

  awk -v begin="$begin" -v end="$end" -v block_path="$block_path" '
    $0 == begin {
      while ((getline line < block_path) > 0) {
        print line
      }
      close(block_path)
      skip = 1
      next
    }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$input_path"
}
