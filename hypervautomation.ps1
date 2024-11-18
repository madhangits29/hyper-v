# This script is used to create Hyper-V virtual machines.
# You need to choose the type of switch and OS path; other settings will be created by this script.

# 1. RAM Calculation
# Function to calculate available RAM

function Get-AvailableRAM {
    $availableRAM = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    Write-Host "Available RAM: ${availableRAM}MB" -ForegroundColor Cyan
    return $availableRAM
}

# Get available RAM
$availableRAM = Get-AvailableRAM
if ($availableRAM -le 3800) {
    Write-Host "RAM is less than the required 3800MB: Try to free some space" -ForegroundColor Red
    exit
} else {
    Write-Host "RAM meets the requirement." -ForegroundColor Green
}

# ----------- Checking Hyper-V Status and Scheduling Script at Startup if Necessary ----------- #

$taskName = "MyPowerShellScriptTask"
$scriptPath = (Get-Location).Path + "\hypervautomation.ps1"

# Define the PowerShell command to run the script
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

# Function to add the script to Task Scheduler for auto-run on next boot
function Add-ScriptToRunOnStartup {
    # Remove any existing scheduled task with the same name
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    # Register a new scheduled task to run once at startup
    Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName $taskName -Force
}

# Check the Hyper-V status
$hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

if ($hyperVFeature.State -eq "Enabled") {
    Write-Output "Hyper-V is Enabled"
    
    # Remove the scheduled task after verifying Hyper-V is enabled
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
} elseif ($hyperVFeature.State -eq "Disabled") {
    Write-Output "Hyper-V is Disabled"
    
    $enableHyperV = Read-Host -Prompt "Press Y to enable Hyper-V and restart, or N to exit"

    if (($enableHyperV -eq 'Y') -or ($enableHyperV -eq 'y')) {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All
        
        # Schedule the script to run on startup after restart
        Add-ScriptToRunOnStartup

        # Restart the computer
        Restart-Computer -Force
    } elseif (($enableHyperV -eq 'N') -or ($enableHyperV -eq 'n')) {
        Write-Output "Exiting without enabling Hyper-V."
    } else {
        Write-Output "Invalid input. Exiting."
    }
} else {
    Write-Output "Could not determine the state of Hyper-V"
}

# ------------------------ Switch Implementation ---------------------------------------------

Write-Host "### Please Select the Switch Type You Want to Create ###" -ForegroundColor Cyan
[int]$switchChoice = Read-Host "1. Internal Switch  2. External Switch  3. Default"

if ($switchChoice -eq 1) {
    New-VMSwitch -Name "IntSwitch" -SwitchType Internal
    Write-Output "Internal switch 'IntSwitch' created."
}
elseif ($switchChoice -eq 2) {
    # Get a list of available network adapters
    $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    Write-Host "Available Network Adaptors " -ForegroundColor Cyan
    $networkAdapters | ForEach-Object { Write-Output "$($_.Name) - Status: $($_.Status)" }

    # Ask the user to input the adapter name
    $selectedAdapterName = Read-Host -Prompt "Enter the name of the network adapter to use for the new virtual switch"

    # Verify if the entered adapter name exists
    $selectedAdapter = $networkAdapters | Where-Object { $_.Name -eq $selectedAdapterName }

    if ($null -ne $selectedAdapter) {
        # Create the virtual switch with the specified adapter
        New-VMSwitch -Name "ExtSwitch" -NetAdapterName $selectedAdapter.Name -AllowManagementOS $true
        Write-Output "External switch 'ExtSwitch' created on adapter $($selectedAdapter.Name)."
    } else {
        Write-Output "Invalid adapter name. Exiting..."
    }
}
elseif ($switchChoice -eq 3) {
    # Check if the "Default Switch" exists
    $defaultSwitch = Get-VMSwitch | Where-Object { $_.SwitchType -eq 'Internal' -and $_.Name -eq 'Default Switch' }

    if ($null -ne $defaultSwitch) {
        Write-Output "Using existing 'Default Switch'. No additional configuration needed."
    } else {
        Write-Output "Default Switch is not available on this system."
    }
} else {
    Write-Output "Invalid choice. Exiting without creating a switch."
}
