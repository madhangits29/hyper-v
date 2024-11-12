#This script is used to create Hyper-v virtual machines.
#you need choose type of switch and Os path other will be created by this script
#1.Ram calculation

#Calculation of ram
#Function to calculate the RAM Details

function Get-AvailableRAM {
    $ramUsage = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    Write-Host "Available RAM: ${ramUsage}MB" -ForegroundColor Cyan
    return $ramUsage
}

# Get available RAM
$availableRAM = Get-AvailableRAM
if ($availableRAM -le 3800) {
    Write-Host "RAM is less than the required 3800MB: Try to free some space" -ForegroundColor Red
    exit
} else {
    Write-Host "RAM meets the requirement." -ForegroundColor Green
}
 #-----------Checking Hyper-V Status and Scheduling Script at Startup if Necessary-----------# 

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
$feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

if ($feature.State -eq "Enabled") {
    Write-Output "Hyper-V is Enabled"
    
    # Remove the scheduled task after verifying Hyper-V is enabled
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
} elseif ($feature.State -eq "Disabled") {
    Write-Output "Hyper-V is Disabled"
    
    $cmd = Read-Host -Prompt "Press Y to enable Hyper-V and restart, or N to exit"

    if (($cmd -eq 'Y') -or ($cmd -eq 'y')) {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All
        
        # Schedule the script to run on startup after restart
        Add-ScriptToRunOnStartup

        # Restart the computer
        Restart-Computer -Force
    } elseif (($cmd -eq 'N') -or ($cmd -eq 'n')) {
        Write-Output "Exiting without enabling Hyper-V."
    } else {
        Write-Output "Invalid input. Exiting."
    }
} else {
    Write-Output "Could not determine the state of Hyper-V"
}


