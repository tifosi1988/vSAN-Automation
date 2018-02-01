## Usage
- To let a host or cluster go into Maintenance Mode, just run: 
```
.\Vsan-ClusterMaintenance.ps1
```

- After maintenance, to make the VMs balanced and evenly distributed in the cluster, run: 
```
.\Vsan-ClusterMaintenance.ps1 -c
```

## Details
### Step 1. Connect to vCenter
Determine if already connected to a vCenter or not. 
1.	When you run the script for the first time, enter the vCenter connection information as prompted.
2.	Running the script for 2nd time prompts to determine if you want to connect again/another vCenter. 
### Step 2. Select a maintenance type
Select a maintenance type. (Default: 1)
1.	Specify a host. Migrate the VMs on it to other hosts. Then put the specified host into maintenance mode.
2.	Evacuate a whole cluster. Migrate all the VMs in the cluster to another cluster. Then put the whole cluster into maintenance mode.
Assign an alphanumeric character to each host or cluster and select one.
### Step 3. Select a vSAN data evacuation method
Select an option to set the migration mechanism for the Virtual SAN data that will be enforced before the hosts enter maintenance mode. (Default: 2)
1.	Full
2.	Ensure Accessibility
3.	No Data Migration
### Step 4. Select a destination host for VMs
Select the mode for destination host selection. (Default: 1)
1.	Random selection.
2.	Generate a weekly report of the ESXi hosts about CpuMaxUsage, MemMaxUsage, DiskMaxLatency(ms), DiskMaxUsage(KBps), NetMaxUsage(KBps) and manually select.
### Step 5. VMotion the VMs
The script will automatically move the VMs off to other hosts using vMotion.
### Step 6. Put the host or cluster into maintenance mode
The script will automatically put the host or cluster into maintenance mode. If evacuating the whole cluster, user should determine if the script puts the next host into maintenance mode at the same time or not.
