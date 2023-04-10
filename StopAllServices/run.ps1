# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# Deallocate all Running VMs that do not have the tag {AlwaysOn: True}
$tagName = "AlwaysOn"
$tagValue = "True"

$vms = Get-AzVM
$filteredVMs = $vms | Where-Object { $_.Tags[$tagName] -ne $tagValue}

foreach ($filteredVM in $filteredVMs) {
    $vmStatus = Get-AzVM -ResourceGroupName $filteredVM.ResourceGroupName -Name $filteredVM.Name -Status
    $vmName = $filteredVM.Name 

    if ($vmStatus.Statuses[1].DisplayStatus -eq "VM deallocated") {
        Write-Host "${vmName} is already deallocated."
    }
    else {
        Write-Host "Stopping ${vmName}.."
        Stop-AzVM -ResourceGroupName $filteredVM.ResourceGroupName -Name $filteredVM.Name -Force -AsJob
    }
    
}

# Remove all Route Tables from Subnets since a FW that was on before won't be anymore
# Leaving a route table that has a route for a deallocated FW will cause routing issues
$rt = Get-AzRouteTable
$rtSubnets = $rt.Subnets
foreach ($rtSubnet in $rtSubnets) {
    $rtSubnetId = $rtSubnet.Id

    $rtSubnetIdSplit = $rtSubnetId -split "/"

    $RGName = $rtSubnetIdSplit[4]
    $VNETName = $rtSubnetIdSplit[8]
    $SubnetName = $rtSubnetIdSplit[10]
    
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNETName
    $subnetInfo = $vnet.Subnets
    $specificSubnetInfo = $subnetInfo | Where-Object Name -eq $SubnetName
    $subnetAddressPrefix = $specificSubnetInfo.AddressPrefix
    Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $SubnetName -AddressPrefix $subnetAddressPrefix -RouteTable $null
    $vnet | Set-AzVirtualNetwork -AsJob
}

# Stopping all Application Gateways that do not have the tag {AlwaysOn: True}
$tagName = "AlwaysOn"
$tagValue = "True"

$appgws = Get-AzApplicationGateway
$filteredAppGWs = $appgws | Where-Object { $_.Tag[$tagName] -ne $tagValue}

foreach ($filteredAppGW in $filteredAppGWs) {
    $appgwName = $filteredAppGW.Name 
    if ($filteredAppGW.OperationalState -eq "Stopped") {
        Write-Host "${appgwName} is already deallocated."
    }
    elseif ($filteredAppGW.OperationalState -eq "Running") {
        Write-Host "The Application Gateway is running.."
        Write-Host "Stopping ${appgwName}.."
        Stop-AzApplicationGateway -ApplicationGateway $filteredAppGW -AsJob
    }
    else {
        Write-Host "Strange Error.  Application Gateway is currently: "
        Write-Host $filteredAppGW.OperationalState
        
    }
}

# Stopping all Azure Firewalls that do not have the tag {AlwaysOn: True}
$tagName = "AlwaysOn"
$tagValue = "True"

$AzFWs = Get-AzFirewall
$filteredAzFWs = $AzFWs | Where-Object { $_.Tag[$tagName] -ne $tagValue}

foreach ($filteredAzFW in $filteredAzFWs) {
    $fw = Get-AzFirewall -ResourceGroupName $filteredAzFW.ResourceGroupName -Name $filteredAzFW.Name
    $fw.Deallocate()
    $fw | Set-AzFirewall -AsJob
}


# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
