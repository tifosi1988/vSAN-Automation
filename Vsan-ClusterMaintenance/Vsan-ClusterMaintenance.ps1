# Disclaimer: This script is not officially supported by VMware. Use with your own risk.
# Purpose:    For a vSAN cluster without DRS, this script automatically migrate the VMs off a host or a cluster.
#             Then it also automatically put the host or cluster into maintenance mode.
#             This eliminates the manual work for putting a host into Maintenance Mode one by one.
# Author:     Jing Luo
#             Victor Shi Chen (shic@vmware.com)

# Usage:
# To let a host or cluster go into Maintenance Mode, just run: .\Vsan-ClusterMaintenance.ps1
# After maintenance, to make the VMs balanced and evenly distributed in the cluster, run: .\Vsan-ClusterMaintenance.ps1 -c

param ([switch] $c)

# Connect to vCenter
Write-Host "Connecting to VI Server"
$global:DefaultVIServer

$newServer = "false"
if ($global:DefaultVIServer) {
    $viserver = $global:DefaultVIServer.Name
    Write-Host "$VIServer is connected." -ForegroundColor green -BackgroundColor blue
    $in = Read-Host "If you want to connect again/another vCenter? Yes[Y] or No[N](Default: N)"
	if($in -eq "Y"){
	$newServer = "true"
	}
	if ($newServer -eq "true") {
    Disconnect-VIServer -Server "$viserver" -Confirm:$False
	$VCServer = Read-Host "Enter the vCenter server name" 
	$viserver = Connect-VIServer $VCServer  
		if ($VIServer -eq ""){
		Write-Host
		Write-Host "Please input a valid credential"
		Write-Host
		exit
		}	
    }
}else{
	$VCServer = Read-Host "Enter the vCenter server name" 
	$VIServer = Connect-VIServer $VCServer  
	if ($VIServer -eq ""){
		Write-Host
		Write-Host "Please input a valid credential"
		Write-Host
		exit
	}
}

if($c) {
    $clusterlist = @()
    $clusterlist += Get-Cluster -Server $VIServer| Sort-Object Name
    $length = $clusterlist.Length
    $clusters = @()
    $balance_all_clusters = Read-Host "Found $length clusters in this vCenter. Balance all of them ? Yes[Y] or No[N](Default: Y)"
    if (!$balance_all_clusters -or ($balance_all_clusters -eq "Y") -or ($balance_all_clusters -eq "Yes")) {
        $clusters += $clusterlist
    }
    else {
        Write-Host  
        Write-Host "Cluster List:"
	    Write-Host
	    $i=0
	    foreach ($acluster in $clusterlist) {
	        $i++;
	        Write-Host "[$i] : $acluster"
	    }
        $no = Read-Host "Select a cluster from the list to balance the VMs (by typing its number and pressing Enter)"  
	    if($no -gt "$i" -or $no -lt "1"){
		    Write-Host "Parameter error! Please input the number: 1-$i" -ForegroundColor red -BackgroundColor blue
	        $no = Read-Host "Select a cluster from the list(by typing its number and pressing Enter)"  
	    }
	    $i=0 
	    foreach ($acluster in $clusterlist) {
	        $i++;
	        if($no -eq $i){
			    $clusters += $acluster
		    }
	    }
    }

    foreach ($cluster in $clusters) {
        $vsanDatastore = Get-Datastore -RelatedObject $cluster | where {$_.type -eq "vsan"}
        $vmhosts = Get-VMHost -Location $cluster | Sort-Object Name

        foreach ($ahost in $vmhosts) {
		    if ($ahost.State -eq "Maintenance") {
                $exit_maintenance_select = "Y"
                $exit_maintenance_select = Read-Host "Found the host $ahost is already in MaintenanceMode, let the host $ahost exit MaintenanceMode? Yes[Y] or No[N](Default: Y)"
                if (!$exit_maintenance_select -or ($exit_maintenance_select -eq "Y") -or ($exit_maintenance_select -eq "Yes")) {
                    Set-VMHost $ahost -State "Connected"
                }
            }
	    }

        $all_vms_in_cluster = Get-VM -Location $cluster -Datastore $vsanDatastore
        $avg_vm_count = [int] ($all_vms_in_cluster.length / $vmhosts.length)
        $migrate_count = (1..$vmhosts.length)
        $migrate_vms = @()

        $i = 0
        foreach ($vmhost in $vmhosts) {
            $vms = $all_vms_in_cluster | where {$_.VMHost -eq $vmhost}
            if ($vms.length -lt $avg_vm_count) {
                $migrate_count[$i] = $avg_vm_count - $vms.length
            }
            else {
                $migrate_count[$i] = 0
                for ($k = 0; $k -lt ($vms.length - $avg_vm_count); $k++) {
                    $migrate_vms += $vms[$k]
                }
            }
            $i++
        }

        $start_index = 0
        for ($i = 0; $i -lt $migrate_count.length; $i++) {
            if ($migrate_count[$i] -gt 0) {
                for ($k = 0; $k -lt $migrate_count[$i]; $k++) {
                    Move-VM -VM $migrate_vms[$k + $start_index] -Destination $vmhosts[$i] -Confirm:$false -RunAsync:$true -Datastore $vsanDatastore
                }
                $start_index += $migrate_count[$i]
            }  
        }
    }
    Write-Host "The virtual machines are distributed evenly in the cluster now. Program exit."
    exit
}

# Choose a maintenance type:
# 1. Specify a host. Migrate the VMs on it to other hosts. Then put the specified host into maintenance mode.
# 2. Evacuate a whole cluster. Migrate all the VMs in the cluster to another cluster. Then put the whole cluster into maintenance mode.
$type = Read-Host "Choose the type that you want to place in maintenance mode:"1" for vmHost and "2" for cluster(Default: 1)"

if ($type -eq "2" ) {
    
    $clusterlist = Get-Cluster -Server $VIServer| Sort-Object Name
	$clusterlist
	if(!$clusterlist){
		Write-Host "Their is no cluster." -ForegroundColor Red -BackgroundColor blue
		return
	}
	Write-Host  
    Write-Host "Cluster List:"
	Write-Host
	$i=0 
	foreach ($acluster in $clusterlist) {
	    $i++;
	    Write-Host "[$i] : $acluster"
	}
    $no = Read-Host "Select a cluster from the list(by typing its number and pressing Enter)"  
	if($no -gt "$i" -or $no -lt "1"){
		Write-Host "Parameter error! Please input the number: 1-$i" -ForegroundColor red -BackgroundColor blue
	    $no = Read-Host "Select a cluster from the list(by typing its number and pressing Enter)"  
	}
	$i=0 
	foreach ($acluster in $clusterlist) {
	    $i++;
	    if($no -eq $i){
			$srccluster = $acluster
			$srchosts = Get-Cluster $srccluster|Get-VMHost
			Write-Host "Set $acluster into maintenance mode"   -ForegroundColor green -BackgroundColor blue
		}
	}
}
else {
    $hostlist = Get-VMHost -Server $VIServer| Sort-Object Name
	$hostlist
	if(!$hostlist){
		Write-Host "Their is no host."  -ForegroundColor red -BackgroundColor blue
		return
	}

    foreach ($ahost in $hostlist) {
		if ($ahost.State -eq "Maintenance") {
            $exit_maintenance_select = "Y"
            $exit_maintenance_select = Read-Host "Found the host $ahost is already in MaintenanceMode, let the host $ahost exit MaintenanceMode? Yes[Y] or No[N](Default: Y)"
            if (!$exit_maintenance_select -or ($exit_maintenance_select -eq "Y") -or ($exit_maintenance_select -eq "Yes")) {
                Set-VMHost $ahost -State "Connected"
            }
        }
	}

	Write-Host 
	Write-Host "VMHost List:"
	Write-Host
	$i=0 
	foreach ($ahost in $hostlist) {
	    $i++;
	    Write-Host "[$i] : $ahost"
	}

    $no = Read-Host "Select a ESXi host from the list(by typing its number and pressing Enter)"
	if($no -gt "$i" -or $no -lt "1"){
		Write-Host "Parameter error! Please input the number: 1-$i" -ForegroundColor red -BackgroundColor blue
	    $no = Read-Host "Select a ESXi host from the list(by typing its number and pressing Enter)"  
	}
	$i=0 
	 foreach ($ahost in $hostlist) {
		$i++;
	    if($no -eq $i){
			$srccluster = $ahost
			Write-Host "Set $ahost into maintenance mode"  -ForegroundColor green -BackgroundColor blue
		}
	 }
    $srchosts = Get-VMHost -Name $srccluster
}

    # Select a vSAN data evacuation method
    $DataMigrationMode =  Read-Host "vSAN data might reside on the hosts in a vSAN cluster. Select an option to set the migration mechanism for the vSAN data that will be enforced before the hosts enter maintenance mode.
    ""1"" for Full
    ""2"" for EnsureAccessibility
    ""3"" for NoDataMigration(Default: 2)" 

    if ($DataMigrationMode -eq "3") {
        $ws = New-Object -ComObject WScript.Shell  
        $wsr = $ws.popup("This option may cause potential data loss if there is a successive failure. Are you sure to continue?",0,"Warning",1 + 64)
        if ($wsr -eq "1") {
            $DataMigrationMode = "NoDataMigration"
        }
        else {
            $DataMigrationMode =  Read-Host "vSAN data might reside on the hosts in a vSAN cluster. Select an option to set the migration mechanism for the vSAN data that will be enforced before the hosts enter maintenance mode.
            ""1"" for Full
            ""2"" for EnsureAccessibility"
            if ($DataMigrationMode -eq "1") {
                $DataMigrationMode = "Full"
            }
            else {
                $DataMigrationMode = "EnsureAccessibility"
            }
        }
    }
    elseif ($DataMigrationMode -eq "1") {
        $DataMigrationMode = "Full"
    }
    else {
        $DataMigrationMode = "EnsureAccessibility"
    }
  
# Get the list of source hosts and desination hosts
foreach ($srchost in $srchosts) {
    $srchost = Get-VMHost -Name $srchost
    if ($type -eq "2") {
        $srccluster = Get-Cluster -Name $srccluster
        $pcluster = Get-Cluster| where{$_.Name -ne $srccluster.Name}
        $dstcluster = $pcluster | Get-Random
    }
    else {
        $srccluster = Get-Cluster -Name $srchost.Parent
        $dstcluster = Get-Cluster -Name $srchost.Parent
    }

    $vmhs = Get-VMHost -Location $dstcluster | where {$_.Name -ne $srchost.Name -and $_.State -eq "Connected"} | Sort-Object Name
    $vmguests = Get-VM -Location $srccluster

    # The mode for destination host selection:
    # 1. Random selection;
    # 2. Generate a weekly report of the ESXi hosts about CpuMaxUsage, MemMaxUsage, DiskMaxLatency_ms, DiskMaxUsage_KBps, NetMaxUsage_KBps and print out. 
    $priority = Read-Host "Destination host selection: "1" for random selection and "2" for generating host performance reports and manually selecting.(Default: 1)"
    if ($priority -eq "2") {
	    $Report = @()
	    foreach ($vmh in $vmhs) {
		    $myObj = "" | Select-Object HostName, CpuMaxUsage, MemMaxUsage, DiskMaxLatency_ms, DiskMaxUsage_KBps, NetMaxUsage_KBps
            $myObj.HostName = (Get-VMHost -name $vmh).Name
            $myObj.CpuMaxUsage = "{0:N2}%" -f (Get-VMHost -name $VMH | Get-Stat -Start ((Get-Date).adddays(-7)) -Finish (Get-Date) -Stat Cpu.Usage.Average | Measure-Object -Maximum -Property Value).Maximum
            $myObj.MemMaxUsage = "{0:N2}%" -f (Get-VMHost -name $VMH | Get-Stat -Start ((Get-Date).adddays(-7)) -Finish (Get-Date) -Stat Mem.Usage.Average | Measure-Object -Maximum -Property Value).Maximum
            $myObj.DiskMaxLatency_ms = (Get-VMHost -name $VMH | Get-Stat -Start ((Get-Date).adddays(-7)) -Finish (Get-Date) -Stat Disk.maxtotallatency.latest | Measure-Object -Maximum -Property Value).Maximum
            $myObj.DiskMaxUsage_KBps = (Get-VMHost -name $VMH | Get-Stat -Start ((Get-Date).adddays(-7)) -Finish (Get-Date) -Stat Disk.Usage.Average | Measure-Object -Maximum -Property Value).Maximum
            $myObj.NetMaxUsage_KBps = (Get-VMHost -name $VMH | Get-Stat -Start ((Get-Date).adddays(-7)) -Finish (Get-Date) -Stat Net.Usage.Average | Measure-Object -Maximum -Property Value).Maximum
            $Report += $myObj
            Write-Host "$vmh Done!"
        }

        # Print the host performance report and select a target host.
        $Report 
        $dsthost = Read-Host "Input name of the destination host:"
    }
    else {
        $dsthost = $vmhs | Get-Random
	}

    $datastores = Get-VMHost $dsthost|Get-Datastore 
    foreach ($datastore in $datastores) {
        if ($datastore -match "vsan") {
            $dstdatastore = $datastore
        }
    }
		
    # vMotion the VMs
    foreach ($vmguest in $vmguests) {
        if ($vmguest.VMHost -like $srchost.Name) {
            Write-Host "Move VM $vmguest to $dsthost..."
            Move-VM -VM $vmguest -Destination $dsthost -Confirm:$false -RunAsync:$true -Datastore $dstdatastore
        }
    }

    # Put a host into maintenance mode.
    Write-Host "Set VMHost $srchost into Maintenance Mode..."
    Set-VMHost $srchost -State "Maintenance" -VsanDataMigrationMode "$DataMigrationMode"
    if ($type -eq "2") {
        $go = Read-Host "Put the next host into maintenance mode? Yes[Y] or No[N](Default: Y)"
    }

    if ($go -eq "n" -or $go -eq "no") {
    Write-Host "Exit!"
    return;
    }
}