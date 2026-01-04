# Idempotent Hyper-V installer + test VMs

# Install Hyper-V if not present. If installation requires restart, restart and exit;
# the post-install step will run after reboot.
if (-not (Get-WindowsFeature -Name Hyper-V).Installed) {
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
    exit 0
}

# Ensure VM storage folder exists
$vmPath = "C:\VMs"
if (-not (Test-Path $vmPath)) {
    New-Item -Path $vmPath -ItemType Directory -Force | Out-Null
}

# Create an Internal switch if missing
if (-not (Get-VMSwitch -Name "InternalSwitch" -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name "InternalSwitch" -SwitchType Internal | Out-Null
}

# Create test VMs if they don't exist
if (-not (Get-VM -Name "TestVM01" -ErrorAction SilentlyContinue)) {
    New-VM -Name "TestVM01" -MemoryStartupBytes 4GB -Generation 2 -NewVHDPath "$vmPath\TestVM01.vhdx" -NewVHDSizeBytes 60GB -SwitchName "InternalSwitch" | Out-Null
}

if (-not (Get-VM -Name "TestVM02" -ErrorAction SilentlyContinue)) {
    New-VM -Name "TestVM02" -MemoryStartupBytes 4GB -Generation 2 -NewVHDPath "$vmPath\TestVM02.vhdx" -NewVHDSizeBytes 60GB -SwitchName "InternalSwitch" | Out-Null
}
