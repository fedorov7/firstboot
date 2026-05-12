write_step "Setting up reusable ML Python environment..."

if ! command_exists uv; then
  write_warn "uv not available. Run python module first to install ML packages."
  return
fi

if [[ -z "$ML_ENVIRONMENT_PATH" ]]; then
  ML_ENVIRONMENT_PATH="$HOME/.virtualenvs/firstboot-ml"
fi

ml_packages=()
while IFS= read -r package_name; do
  ml_packages+=("$package_name")
done < <(split_csv "$ML_PYTHON_PACKAGES")
if [[ ${#ml_packages[@]} -eq 0 ]]; then
  write_warn "ML_PYTHON_PACKAGES is empty. Skipping ML package installation."
  return
fi

uv python install "$ML_PYTHON_VERSION"

if [[ ! -f "$ML_ENVIRONMENT_PATH/pyvenv.cfg" ]]; then
  write_step "Creating ML virtual environment at $ML_ENVIRONMENT_PATH..."
  uv venv --python "$ML_PYTHON_VERSION" "$ML_ENVIRONMENT_PATH"
  write_ok "ML virtual environment created"
else
  write_skip "ML virtual environment already exists"
fi

ml_python="$ML_ENVIRONMENT_PATH/bin/python"
if [[ ! -x "$ml_python" ]]; then
  write_warn "ML Python executable not found: $ml_python"
  return
fi

write_step "Installing ML packages into $ML_ENVIRONMENT_PATH..."
uv pip install --python "$ml_python" "${ml_packages[@]}"
write_ok "ML Python packages installed"

if [[ "$ML_TIMESFM_ENABLED" -eq 1 ]]; then
  write_step "Installing TimesFM runtime ($ML_TIMESFM_BACKEND)..."
  case "$ML_TIMESFM_BACKEND" in
    torch-default|torch-cpu)
      uv pip install --python "$ml_python" 'timesfm[torch]'
      ;;
    flax)
      uv pip install --python "$ml_python" 'timesfm[flax]'
      ;;
    *)
      write_warn "Unsupported ML_TIMESFM_BACKEND '$ML_TIMESFM_BACKEND'. Use torch-default, torch-cpu, or flax."
      ;;
  esac
  write_ok "TimesFM runtime installed"
fi

"$ml_python" -m ipykernel install --user --name firstboot-ml --display-name "Python (firstboot-ml)"
write_ok "Jupyter kernel registered: Python (firstboot-ml)"
