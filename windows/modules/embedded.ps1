Write-Step "Installing embedded systems tooling..."

Install-WingetPackage -Id 'xpack-dev-tools.openocd-xpack' -Name 'OpenOCD xPack'

Install-CargoBinary -Command 'probe-rs' -Package 'probe-rs-tools'

Write-Warn "Install vendor USB/debug drivers manually when required: ST-Link, J-Link, CMSIS-DAP, or board-specific WinUSB drivers."
