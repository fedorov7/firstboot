Write-Step "Installing UEFI, QEMU, and firmware tooling..."

$uefiPackages = @(
    @{ Id = 'NASM.NASM';                          Name = 'NASM' }
    @{ Id = 'SoftwareFreedomConservancy.QEMU';    Name = 'QEMU' }
    @{ Id = 'LLVM.LLVM';                          Name = 'LLVM tools' }
)

foreach ($pkg in $uefiPackages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}

Install-UvTool -Command 'binwalk' -Package 'binwalk'
