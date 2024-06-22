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