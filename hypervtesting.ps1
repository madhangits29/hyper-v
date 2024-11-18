param (
    [Parameter(Mandatory = $false)]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Internal", "External", "Default")]
    [string]$SwitchType,

    [Parameter(Mandatory = $false)]
    [string]$ISOPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet("1", "2")]
    [string]$Generation
)

function Get-AvailableRAM {
    $availableRAM = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    Write-Host "Available RAM: $($availableRAM) MB" -ForegroundColor Cyan
    return $availableRAM
}

# RAM check
$availableRAM = Get-AvailableRAM
if ($availableRAM -le 3800) {
    Write-Host "Insufficient RAM detected: $($availableRAM) MB. At least 3800 MB is required. Please free up memory and try again." -ForegroundColor Red
    exit
} else {
    Write-Host "Sufficient RAM detected: $($availableRAM) MB. Continuing..." -ForegroundColor Green
}

# Setup task parameters
$taskName = "HyperVAutomation"
$scriptPath = (Get-Location).Path + "\hypervautomation.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

function Add-ScriptToRunOnStartup {
    Write-Host "Scheduling script to run at startup..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName $taskName -Force
    if (Get-ScheduledTask -TaskName $taskName) {
        Write-Host "Task '$taskName' successfully registered."
    } else {
        Write-Host "Failed to create scheduled task '$taskName'." -ForegroundColor Red
    }
}

# Hyper-V Status Check
$hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

if ($hyperVFeature.State -eq "Enabled") {
    Write-Host "Hyper-V is Enabled"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
} elseif ($hyperVFeature.State -eq "Disabled") {
    Write-Host "Hyper-V is Disabled"
    $enableHyperV = Read-Host -Prompt "Press Y to enable Hyper-V and restart, or N to exit"

    if (($enableHyperV -eq 'Y') -or ($enableHyperV -eq 'y')) {
        Add-ScriptToRunOnStartup
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All
        Restart-Computer -Force
    } else {
        Write-Host "Exiting without enabling Hyper-V."
        exit
    }
} else {
    Write-Host "Could not determine the state of Hyper-V"
    exit
}

# VM Defaults
$memoryStartupBytes = 2GB
$vhdSizeBytes = 40GB
$vmPath = "C:\VMs\$VMName"
$vhdPath = "$vmPath\$VMName.vhdx"

if (!(Test-Path -Path $vmPath)) {
    New-Item -ItemType Directory -Path $vmPath
    Write-Host "Created VM directory at $vmPath."
}

# Switch Selection
$switchName = ""
if ($SwitchType -eq "Default") {
    $defaultSwitch = Get-VMSwitch | Where-Object { $_.SwitchType -eq 'Internal' -and $_.Name -eq 'Default Switch' }
    if ($null -ne $defaultSwitch) {
        $switchName = $defaultSwitch.Name
        Write-Host "Using 'Default Switch'."
    } else {
        Write-Host "Default Switch not found. Exiting..."
        exit
    }
}
elseif ($SwitchType -eq "Internal") {
    $switchName = "IntSwitch"
    if (!(Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue)) {
        New-VMSwitch -Name $switchName -SwitchType Internal
        Write-Host "Created internal switch '$switchName'."
    }
}
elseif ($SwitchType -eq "External") {
    $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    if ($networkAdapters.Count -gt 0) {
        Write-Host "Available network adapters for external switch creation:"
        $networkAdapters | ForEach-Object { 
            $index = $networkAdapters.IndexOf($_)
            Write-Host "${index}: $($_.Name) - Status: $($_.Status)"
        }
        [int]$adapterIndex = Read-Host "Enter the index number of the network adapter to use"
        if ($adapterIndex -ge 0 -and $adapterIndex -lt $networkAdapters.Count) {
            $selectedAdapter = $networkAdapters[$adapterIndex]
            $switchName = "ExtSwitch"
            if (!(Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue)) {
                New-VMSwitch -Name $switchName -NetAdapterName $selectedAdapter.Name -AllowManagementOS $true
                Write-Host "Created external switch '$switchName' on adapter '$($selectedAdapter.Name)'."
            }
        } else {
            Write-Host "Invalid adapter selection. Exiting..."
            exit
        }
    } else {
        Write-Host "No available network adapters found for creating an external switch. Exiting..."
        exit
    }
}

# VM Creation
New-VM -Name $VMName `
       -MemoryStartupBytes $memoryStartupBytes `
       -Path $vmPath `
       -NewVHDPath $vhdPath `
       -NewVHDSizeBytes $vhdSizeBytes `
       -Generation $Generation `
       -SwitchName $switchName
Write-Host "Virtual Machine '$VMName' created with $memoryStartupBytes of RAM and a $vhdSizeBytes VHD."

if (Test-Path -Path $ISOPath) {
    Add-VMDvdDrive -VMName $VMName -Path $ISOPath
    Write-Host "ISO file '$ISOPath' mounted to VM '$VMName'."
} else {
    Write-Host "ISO file '$ISOPath' not found. Exiting..."
    exit
}

# Uncomment to start VM after creation
# Start-VM -Name $VMName
# Write-Host "Virtual Machine '$VMName' has been started."
