param (
    [string]$subscriptionId,
    [string]$resourceGroupName,
    [string]$imageId
)
 
$adminUsername = "rootadmin"
$adminPassword = "Microsoft123!"
 
# Path to the log file
$logFilePath = Join-Path (Get-Location).Path "image_creation_logs.txt"
 
# Check if log file exists and contains the necessary values
if (Test-Path $logFilePath) {
    Write-Host "Log file found. Attempting to retrieve parameters from it."
 
    # Try to read the log file and extract values
    $logContent = Get-Content -Path $logFilePath
    $subscriptionId = ($logContent | Select-String -Pattern "Subscription ID: (\S+)").Matches.Groups[1].Value
    $resourceGroupName = ($logContent | Select-String -Pattern "Resource Group: (\S+)").Matches.Groups[1].Value
    $imageId = ($logContent | Select-String -Pattern "Created Image ID: (\S+)").Matches.Groups[1].Value
 
    # If any of the values are still empty, prompt the user
    if (-not $subscriptionId) {
        $subscriptionId = Read-Host "Enter Subscription ID"
    }
 
    if (-not $resourceGroupName) {
        $resourceGroupName = Read-Host "Enter Resource Group Name"
    }
 
    if (-not $imageId) {
        $imageId = Read-Host "Enter Image ID"
    }
} else {
    # Log file doesn't exist, prompt the user for values
    Write-Host "Log file not found. Prompting for parameters."
    $subscriptionId = Read-Host "Enter Subscription ID"
    $resourceGroupName = Read-Host "Enter Resource Group Name"
    $imageId = Read-Host "Enter Image ID"
}
 
Write-Host "Using Subscription ID: $subscriptionId"
Write-Host "Using Resource Group Name: $resourceGroupName"
Write-Host "Using Image ID: $imageId"
 
 
# Check login context
if (-not (Get-AzContext)) {
    Write-Host "You are not logged in. Please log in first."
    Connect-AzAccount
}
 
# Set the Azure subscription context
Set-AzContext -SubscriptionId $subscriptionId
 
# Get the Virtual Network (VNet) associated with the Resource Group
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName | Where-Object { $_.Subnets.Count -gt 0 }
 
# Check if a VNet was found and has subnets
if ($vnet -and $vnet.Subnets.Count -gt 0) {
    # Fetch the default subnet ID (the first subnet in the VNet)
    $subnetId = $vnet.Subnets[0].Id
    Write-Host "Using default subnet ID: $subnetId"
} else {
    Write-Error "No virtual network or subnets found in resource group '$resourceGroupName'."
    exit
}
 
# Template file path (adjust if needed)
$templateFilePath = Join-Path (Get-Location).Path "Vm-template.json"
 
# Check if template exists
if (-not (Test-Path $templateFilePath)) {
    Write-Host "Template file not found at $templateFilePath. Please check the file path."
    return
}
 
# Prompt for the number of VMs
$numVMs = [int](Read-Host "Enter the number of VMs to create")
 
# Prompt for the name of the first VM
$baseVMName = Read-Host "Enter the base name for VMs (e.g., MY)"
 
# Generate VM configurations with incrementing names
$vms = @()
for ($i = 1; $i -le $numVMs;$i++) {
    # Generate the VM name by appending the incrementing number
    $vmName = "$baseVMName-$i"
 
    # Add the VM configuration to the list
    $vms += @{
        computerName = $vmName
        networkInterfaceName = "NIC-$vmName"
        networkSecurityGroupName = "NSG-$vmName"
        publicIpAddressName = "PIP-$vmName"
        deploymentName = "Vm-template-$i-$(Get-Date -Format 'yyyyMMdd')"
    }
}
 
# Log the number of VMs to be created
Add-Content -Path $logFilePath -Value "Number of VMs to create: $numVMs"
 
# Save the VM names to the current directory
$currentDirectory = $PWD.Path
$vmNamesFileCurrent = "$currentDirectory\vmNames.txt"
 
# Saving VM names to the current directory
$vms | ForEach-Object { $_.computerName } | Out-File -FilePath $vmNamesFileCurrent
 
Write-Host "VM names saved to current directory: $vmNamesFileCurrent"
 
# Deploy each VM in parallel using background jobs
$jobs = @()
foreach ($vm in $vms) {
    $parameters = @{
        imageId = $imageId
        adminUsername = $adminUsername
        adminPassword = $adminPassword  # Plain text password
        computerName = $vm.computerName
        networkInterfaceName = $vm.networkInterfaceName
        subnetId = $subnetId
        networkSecurityGroupName = $vm.networkSecurityGroupName
        publicIpAddressName = $vm.publicIpAddressName
    }
 
    $job = Start-Job -ScriptBlock {
        param (
            $resourceGroupName,
            $templateFilePath,
            $parameters,
            $deploymentName,
            $logFilePath
        )
 
        try {
            # Create a temporary copy of the template file
            $tempTemplateFilePath = [System.IO.Path]::GetTempFileName()
            Copy-Item -Path $templateFilePath -Destination $tempTemplateFilePath -Force
 
            $logMessage = "Starting deployment for VM $($parameters.computerName) at $(Get-Date)"
            Add-Content -Path $logFilePath -Value $logMessage
 
            New-AzResourceGroupDeployment `
                -ResourceGroupName $resourceGroupName `
                -TemplateFile $tempTemplateFilePath `
                -TemplateParameterObject $parameters `
                -DeploymentName $deploymentName `
                -Verbose
 
            $logMessage = "Deployment succeeded for VM $($parameters.computerName) at $(Get-Date)"
            Add-Content -Path $logFilePath -Value $logMessage
 
            # Clean up the temporary template file
            Remove-Item -Path $tempTemplateFilePath -Force
        }
        catch {
            $logMessage = "Deployment failed for VM $($parameters.computerName) with error: $_ at $(Get-Date)"
            Add-Content -Path $logFilePath -Value $logMessage
        }
    } -ArgumentList $resourceGroupName, $templateFilePath, $parameters, $vm.deploymentName, $logFilePath
 
    $jobs += $job
 
    }
 
# Wait for all jobs to complete
$jobs | ForEach-Object { Receive-Job -Job $_ -Wait }
 
# Log the completion of all jobs
Add-Content -Path $logFilePath -Value "All deployments completed at $(Get-Date)"
 
# First script: first_script.ps1
 
Write-Host "Running the first script..."
 
# Ask user if they want to run the second script
$runSecondScript = Read-Host "Do you want to run the S360 Compliance script? (Y/N)"
 
if ($runSecondScript -eq 'Y' -or $runSecondScript -eq 'y') {
    Write-Host "Running the second script..."
    .\S360Compliance.ps1
} else {
    Write-Host "Second script will not be run."
}
