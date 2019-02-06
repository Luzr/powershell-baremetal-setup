# made on 12.8.2018
# updated 2.6.2019
# made for air-san-right
# https://www.tech-coffee.net/2-node-hyperconverged-cluster-with-windows-server-2016/

$server_name = "smb-fileshare"

Rename-Computer $server_name

# rename nic 
$netAdapters = Get-NetAdapter 
$i = 1
$j = 1

foreach ($netAdapter in $netAdapters ){
    $oldDescription = $netAdapter.name 
    $linkspeed = $netAdapter.linkspeed 
    if ($linkspeed -eq "1 Gbps" ){
        $newName = "management-10$i"
        $i = $i +1
        Write-Host "Old Name:" $oldDescription "New Name:" $newName
        $interface | Rename-NetAdapter -NewName $newName
    }
    
    if ($linkspeed -eq "10 Gbps" ){
        $newName = "storage-10$j"
        $i = $i +1
        Write-Host "Old Name:" $oldDescription "New Name:" $newName
        $interface |Rename-NetAdapter -NewName $newName
    }         
}

# add hyper-v roll

Install-WindowsFeature -Name Hyper-V -IncludeManagementTools

# stop copy paste here 
set-timezone "Central Standard Time"

Restart-Computer

# create network team and add nics
# New-NetLbfoTeam -Name lbfo-1 –TeamMembers intel-101, intel-102 -TeamingMode SwitchIndependent -LoadBalancingAlgorithm HyperVPort -Confirm:$false
# New-VMSwitch -Name vSwitch-team-1 –NetAdapterName intel-101,intel-102 -AllowManagementOS $False

# might not work
$NICname = Get-NetAdapter | Where-Object{$_.name -like "intel*"}

New-NetLbfoTeam -Name lbfo-1 –TeamMembers $NICname.Name -TeamingMode SwitchIndependent -LoadBalancingAlgorithm HyperVPort -Confirm:$false
# Set-NetLbfoTeam -Name Hyp1Team -TeamingMode SwitchIndependent
New-VMSwitch -Name vSwitch-team-1 –NetAdapterName lbfo-1 –MinimumBandwidthMode Weight –AllowManagementOS $false


# this makes the network adaptor to manage the host
Add-VMNetworkAdapter -SwitchName vSwitch-team-1 -ManagementOS -Name mgmt-1
Rename-NetAdapter -Name "vEthernet (mgmt-1)" -NewName mgmt-1

$managementNic = "mgmt-101"
if($env:COMPUTERNAME -eq "smb-01"){
    $IP = "172.31.1.51"
}elseif ($env:COMPUTERNAME -eq "smb-02") {
    $IP = "172.31.1.52"
}elseif ($env:COMPUTERNAME -eq "smb-03"){
    $IP = "172.31.1.53"
}elseif ($env:COMPUTERNAME -eq "smb-fileshare"){
    $IP = "172.31.1.50" 
}else {
    Write-Host "no ip will be set"
}
$MaskBits = 24
$Gateway = "172.31.1.1"
$DNS = "172.31.1.10"
$IPType = "IPv4"
# Configure the IP address and default gateway

New-NetIPAddress -InterfaceAlias $managementNic -AddressFamily $IPType -IPAddress $IP -PrefixLength $MaskBits -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $managementNic -ServerAddresses $DNS | Out-Null

# set storage nic ip
$storagesmbfile1 = "192.168.31.50"
$storagesmbfile2 = "192.168.31.40"
$storagesmb011 = "192.168.31.51"
$storagesmb012 = "192.168.31.41"
$storagesmb021 = "192.168.31.42"
$storagesmb022 = "192.168.31.52"
# foreach ($nic in (Get-NetAdapter | Where-Object{ $_.name -like "storage*"})){
# Write-Host $nic.name
# }
if($env:COMPUTERNAME -eq "smb-01"){
    New-NetIPAddress -InterfaceAlias "storage-101" -AddressFamily "IPv4" -IPAddress $storagesmb011  -PrefixLength 24
    New-NetIPAddress -InterfaceAlias "storage-102" -AddressFamily "IPv4" -IPAddress $storagesmb012 -PrefixLength 24
}elseif ($env:COMPUTERNAME -eq "smb-02") {
    New-NetIPAddress -InterfaceAlias "storage-101" -AddressFamily "IPv4" -IPAddress $storagesmb021 -PrefixLength 24
    New-NetIPAddress -InterfaceAlias "storage-102" -AddressFamily "IPv4" -IPAddress $storagesmb022 -PrefixLength 24
}elseif ($env:COMPUTERNAME -eq "smb-03"){
    New-NetIPAddress -InterfaceAlias "storage-101" -AddressFamily "IPv4" -IPAddress $storagesmb031 -PrefixLength 24
    New-NetIPAddress -InterfaceAlias "storage-102" -AddressFamily "IPv4" -IPAddress $storagesmb032 -PrefixLength 24
}elseif ($env:COMPUTERNAME -eq "air-san-right"){
    New-NetIPAddress -InterfaceAlias "storage-201" -AddressFamily "IPv4" -IPAddress $storagesmbfile1 -PrefixLength 24
    New-NetIPAddress -InterfaceAlias "storage-202" -AddressFamily "IPv4" -IPAddress $storagesmbfile2 -PrefixLength 24
}else {
    Write-Host "no ip will be set"
}

# show ips 
Get-NetIPAddress | Where-Object {($_.IPAddress -like "172*") -or ($_.IPAddress -like "192*")} | Format-Table

Set-NetAdapterAdvancedProperty -Name storage-101 -RegistryKeyword “*JumboPacket” -Registryvalue 9014
Set-NetAdapterAdvancedProperty -Name storage-102 -RegistryKeyword “*JumboPacket” -Registryvalue 9014




# Remove any existing IP, gateway from our ipv4 adapter
# foreach ($nic in (Get-NetAdapter | Where-Object{ $_.name -like "mgmt*"})){

#     If (($nic | Get-NetIPConfiguration).IPv4Address.IPAddress) {
#         $nic | Remove-NetIPAddress -AddressFamily "IPv4" -Confirm:$false
#     }

#     If (($nic | Get-NetIPConfiguration).Ipv4DefaultGateway) {
#         $nic | Remove-NetRoute -AddressFamily "IPv4" -Confirm:$false
#     }
# }

# make cluster on other nodes

# restrict smb to rdma 
# run onlyon the hosts
# https://blogs.technet.microsoft.com/josebda/2012/06/28/the-basics-of-smb-multichannel-a-feature-of-windows-server-2012-and-smb-3-0/
# https://www.thomasmaurer.ch/2013/08/hyper-v-over-smb-smb-multichannel/
New-SmbMultichannelConstraint -InterfaceAlias storage-101, storage-102 -ServerName air-san-right


# just for the san

# $sanStorageIP1 = "192.168.31.65"
# $sanStorageIP2 = "192.168.31.66"
# $MaskBits = 24
# $IPType = "IPv4"
# New-NetIPAddress -InterfaceAlias storage-203 -AddressFamily $IPType -IPAddress $sanStorageIP1 -PrefixLength $MaskBits
# New-NetIPAddress -InterfaceAlias storage-204 -AddressFamily $IPType -IPAddress $sanStorageIP2 -PrefixLength $MaskBits


# Get-VMNetworkAdapterVlan -VMNetworkAdapterName "mgmt-1" -ManagementOS
# Enable Remote Desktop
(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null
(Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true

# disable firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# add to domain
Add-Computer smb.airideas.net -Credential smb\anders

Restart-Computer 

# wait if needed
# Start-Sleep 3600 ; Restart-Computer -Confirm:$false
# add windows permssion
# Folder Permissions https://www.eiseverywhere.com/file_uploads/bf03bb24df51ade2daaabfaff4d6d4b1_MON_1110am_Virtualization_Jose_Barreto.pdf
# – MD F:\VMS
# – ICACLS F:\VMS /Inheritance:R
# – ICACLS F:\VMS /Grant Dom\HAdmin:(CI)(OI)F
# – ICACLS F:\VMS /Grant Dom\HV1$:(CI)(OI)F
# – ICACLS F:\VMS /Grant Dom\HV1$:(CI)(OI)F
# make smb share
# http://ilovepowershell.com/2012/09/19/create-network-share-with-powershell-3/
New-SmbShare -Name vm -Path H:\vm -FullAccess smb\administrator, smb\anders, smb\smb-01$, smb\smb-02$  
# might need to make it though windows security  https://www.business.com/articles/powershell-manage-file-system-acl/
(Get-SmbShare –Name VMS).PresetPathAcl | Set-Acl