# Idempotent Hyper-V installer + test VMs with post-reboot continuation via scheduled task

$taskName   = "InstallHyperVPostReboot"

# Use a stable path (Startup tasks often run as SYSTEM; $env:TEMP can differ and break continuity)
$tempDir    = "C:\Temp"
$scriptPath = Join-Path $tempDir "install-hyperv.ps1"

$vmPath     = "C:\VMs"
$logPath    = Join-Path $tempDir "install-hyperv.log"

# Ensure temp dir exists (also used by Terraform extension)
if (-not (Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
}

try { Start-Transcript -Path $logPath -Append | Out-Null } catch {}

function Ensure-PostRebootTask {
    param([string]$Name, [string]$ScriptFile)

    try {
        if (-not (Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue)) {
            $action    = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptFile`""
            $trigger   = New-ScheduledTaskTrigger -AtStartup
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            $settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
            Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        }
    } catch {
        # best-effort; continue
    }
}

# If Hyper-V not installed, register a scheduled task to run this script at startup, then install and restart.
$hyperV = Get-WindowsFeature -Name Hyper-V -ErrorAction SilentlyContinue
if (-not $hyperV -or -not $hyperV.Installed) {

    # Ensure script exists at the stable $scriptPath for the post-reboot scheduled task
    if (-not (Test-Path $scriptPath)) {
        $self = $PSCommandPath
        if ($self -and (Test-Path $self)) {
            Copy-Item -Path $self -Destination $scriptPath -Force
        } else {
            throw "Cannot locate current script path to persist to $scriptPath"
        }
    }

    Ensure-PostRebootTask -Name $taskName -ScriptFile $scriptPath

    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
    exit 0
}

# If scheduled task exists, remove it (we are running post-reboot)
try {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
} catch {}

# Wait briefly for Hyper-V services/module to be ready post-reboot
try {
    Import-Module Hyper-V -ErrorAction Stop
} catch {
    Start-Sleep -Seconds 20
    Import-Module Hyper-V -ErrorAction Stop
}

try {
    $vmms = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
    if ($vmms -and $vmms.Status -ne "Running") {
        Start-Service -Name "vmms" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
    }
} catch {}

# Ensure VM storage folder exists
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

try { Stop-Transcript | Out-Null } catch {}
