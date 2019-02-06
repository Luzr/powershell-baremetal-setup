# made on 12.8.2018
# updated 2.6.2019
# orgin from smb lab domain

$server_name = "server-name"
Rename-Computer $server_name

# rename nic 
$netAdapters = Get-NetAdapterHardwareInfo | Select-Object  InterfaceAlias,InterfaceDescription, Bus,Function | Sort-Object bus
$i = 1
$j = 1
$k = 1

foreach ($netAdapter in $netAdapters){
    $interface = $netAdapter | Get-NetAdapter
    $oldDescription = $interface.InterfaceDescription 
    if ($oldDescription -like "Intel*" ){
        $newName = "intel-10$i"
        $i = $i +1
        Write-Host "Old Name:" $oldDescription "New Name:" $newName
        $interface | Rename-NetAdapter -NewName $newName
    }       
    if ($oldDescription -like "Mellanox ConnectX-3*" ){
        $newName = "storage-10$j"
        $j = $j +1
        Write-Host "Old Name:" $oldDescription "New Name:" $newName
        $interface | Rename-NetAdapter -NewName $newName
    }
    if ($oldDescription -like "Mellanox ConnectX-2*" ){
        $newName = "storage-20$k"
        $k = $k +1
        Write-Host "Old Name:" $oldDescription "New Name:" $newName
        $interface | Rename-NetAdapter -NewName $newName
    }
}

# add hyper-v roll

Install-WindowsFeature -Name Hyper-V -IncludeManagementTools

# stop copy paste here 
set-timezone "Central Standard Time"

Restart-Computer


# create network team and add nics
New-NetLbfoTeam -Name lbfo-1 –TeamMembers intel-101, intel-102, intel-103, intel-104 -TeamingMode SwitchIndependent -LoadBalancingAlgorithm HyperVPort -Confirm:$false
New-VMSwitch -Name vSwitch-team-1 –NetAdapterName lbfo-1 –MinimumBandwidthMode Weight –AllowManagementOS $false -EnableIov $true

# Remove-VMNetworkAdapter -ManagementOS -Name mgmt-1

# this make the network adaptor to manage the host
Add-VMNetworkAdapter -SwitchName vSwitch-team-1 -ManagementOS -Name mgmt-1
Rename-NetAdapter -Name "vEthernet (mgmt-1)" -NewName mgmt-1


$managementNic = "mgmt-1"
$IP = "10.1.10.42"
$MaskBits = 24
$Gateway = "10.1.10.5"
$DNS = "10.1.10.10" 
$IPType = "IPv4"

# Configure the IP address and default gateway

New-NetIPAddress -InterfaceAlias $managementNic -AddressFamily $IPType -IPAddress $IP -PrefixLength $MaskBits -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $managementNic -ServerAddresses $DNS | Out-Null

# set vlans
# $Nic = Get-VMNetworkAdapter -Name $managementNic -ManagementOS
# Set-VMNetworkAdapterVlan -VMNetworkAdapter $Nic -Access -VlanId 100

# check vlans
# Get-VMNetworkAdapterVlan -VMNetworkAdapterName "mgmt-1" -ManagementOS

# Enable Remote Desktop
(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null
(Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true

# disable firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# add to domain
Add-Computer [domain].local -Credential [domain]\[user] -credential [domain]\[user] 

# pause for a sec
Read-Host -Prompt "Press Enter to continue"

# restart
Restart-Computer