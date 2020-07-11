# Optimize-VMDisk

This script was written as a way of easily performing the Optimize-VHD cmdlet that cleans up previously used space and defrags dynamic VHD and VHDX drives used by Hyper-V VMs. Because this operation requires that the VM be shutdown and the disk be mounted ready only it can take some setup to get the disk in the correct state to optimize it. This script will shutdown the VM, mount the disk, optimize the disk,dismount the disk and then start the VM back up. It also provides a report showing the previous, current and amount recovered from the optimization process.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.


### Installing

The recommended method is to install directly from the PSGallery.

```
# Change Powershell prompt to use TLS1.2. This is a requirement for the PSGallery.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Download and install the module from the PSGallery
Install-Module Optimize-VMDisk -Repository PSGallery -Force
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
