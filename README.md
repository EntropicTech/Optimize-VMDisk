# Optimize-VMDisk
Script for optimizing Hyper-V VM disks.

This script was written as a way of easily performing the Optimize-VHD cmdlet that cleans up previously used space and defrags dynamic VHD and VHDX drives used by Hyper-V VMs. Because this operation requires that the VM be shutdown and the disk be mounted ready only it can take some setup to get the disk in the correct state to optimize it. This script will shutdown the VM, mount the disk, optimize the disk and then dismount the disk. It also provides a report showing the previous, current and amount recovered from the optimization process.
