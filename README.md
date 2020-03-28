# Optimize-VMDisk

This script was written as a way of easily performing the Optimize-VHD cmdlet that cleans up previously used space and defrags dynamic VHD and VHDX drives used by Hyper-V VMs. Because this operation requires that the VM be shutdown and the disk be mounted ready only it can take some setup to get the disk in the correct state to optimize it. This script will shutdown the VM, mount the disk, optimize the disk,dismount the disk and then start the VM back up. It also provides a report showing the previous, current and amount recovered from the optimization process.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.


### Installing

First step is to download a copy of the Optimize-VMDisk.ps1 from GitHub and copy it to the Hyper-V server that is hosting the VMs that you'll be performing the optimization on.

Next you'll need to open an administrative powershell window and import the module in.
```
Import-Module C:\scripts\Optimize-VMDisk.ps1
```

### Examples

Shutdown the target VM, optimize any disks attached to it and then start it back up.

```
Optimize-VMDisk -Name ET-DC-02 -Shutdown
```
This will return this output as a psobject.
```
VMName   Disk                           Original(GB) Current(GB) Savings(GB)
------   ----                           ------------ ----------- -----------
ET-DC-02 D:\VMs\ET-DC-02\2019-Core.vhdx           20          14           6

```

## Author

Dillon Childers
