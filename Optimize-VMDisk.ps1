function Optimize-VMDisk {
    <#
        .SYNOPSIS
        This is a cmdlet that will mount, optimize and dismount a VM's disks.

    .DESCRIPTION
        This cmdlet verifies that a VM is turned off, disks are unmounted and that it has no checkpoints.
        If the VM meets all of these requirements it mounts the VM's disks read only and then performs Optimize-VHD on the VM's disks and then dismounts the disk.

    .PARAMETER Name
        This is the name of the VM that you want optimized. Accepts pipeline input from Get-VM.

    .PARAMETER Shutdown
        If used, this will perform Stop-VM -Force on all of the VMs selected to be optimized.
    
    .INPUTS
        Accepts pipeline input from Get-VM.

    .OUTPUTS
        Outputs a PSObject. 
        
    .EXAMPLE
        Optimize-VMDisk -Name ET-DC-02 -Shutdown            
    #>    
    [CmdletBinding()]
    Param(
            [parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
            [ValidateNotNullorEmpty()]
            [string]$Name,
            
            [parameter(Mandatory=$False)]
            [switch]$Shutdown
    )
    Process {
                
        # Collect the VMs we are working with.
        $VM = Get-VM -Name $Name

        # Shutsdown the VM before attempting the optimization process.
        if ($Shutdown) {               
            Write-Verbose "Attempting to shutdown $($VM.Name)."
            try {
                Stop-VM -Name $VM.Name -Force
            } catch {
                Write-Verbose "Shutdown unsuccessful $($VM.Name)."
                Write-Host $_.Exception.Message -ForegroundColor Red 
            }
        }
                       
        # Build variable of the disks connected to this VM.
        Write-Verbose "Gathering VM disk info from $($VM.Name)."
        $VMDisks = Get-VMHardDiskDrive -VMName $Name
        
        # Validate that VM is not running, has no checkpoints and isn't mounted. If all pass then mount,optimize and dismount the disk.
        Write-Verbose "Verifying that $($VM.Name) is turned off."
        if ($VM.State -ne "Off" ) {
            Write-Warning "$($VM.Name) is not turned off. Turn $($VM.Name) off and try again."
            return
        } else {
            Write-Verbose "$($VM.Name) is turned off."            
            $results = $VMDisks | ForEach-Object {
                $Path = $_.Path
                $VHD = Get-VHD -Path $Path
                $AttachCheck = $VHD.Attached
                Write-Verbose "Verifying virtual disk is ready."
                Write-Verbose "Verifying that $($Path) isn't mounted."
                if ($AttachCheck -eq $False) {
                    Write-Verbose "$($Path) is not mounted."
                    if ($Path.Split(".")[1] -eq 'avhdx') {
                        Write-Warning "$($_.VMName) has a checkpoint. Merge the checkpoint and try again."
                        return
                    } else {
                        Write-Verbose "Virtual disk state verified."
                        
                        # Mount the VHD
                        try { 
                            Write-Verbose "Mounting $Path as read only."
                            Mount-VHD -Path $Path -ReadOnly
                        } catch {
                            Write-Host "Couldn't mount $($Path)" -ForegroundColor Red
                            Write-Host $_.Exception.Message -ForegroundColor Red
                        }
                        
                        # Optimize the VHD
                        try {
                            Write-Verbose "Optimizing $Path."
                            $VHDSizePre = $VHD.FileSize
                            Optimize-VHD -Path $Path
                            $VHDSizePost = (Get-VHD -Path $Path).FileSize
                            $VHDSavings = [math]::Round(($VHDSizePre - $VHDSizePost)/1GB)
                            Write-Verbose "Saved $VHDSavings GB."   
                        } catch {
                            Write-Host "Couldn't optimize $($Path)" -ForegroundColor Red
                            Write-Host $_.Exception.Message -ForegroundColor Red                        
                        }
                        
                        # Dismount the VHD
                        try {
                            Write-Verbose "Dismounting $Path."
                            Dismount-VHD -Path $Path
                            Write-Verbose "$Path has been optimized."
                        } catch {
                            Write-Host "Couldn't dismount. $($Path)" -ForegroundColor Red
                            Write-Host $_.Exception.Message -ForegroundColor Red                        
                        }

                        [PSCustomObject]@{
                            VMName = $VM.Name
                            Disk = $Path
                            'Original(GB)' = [math]::Round(($VHDSizePre /1GB))
                            'Current(GB)' = [math]::Round(($VHDSizePost /1GB))
                            'Savings(GB)' = [math]::Round(($VHDSavings /1GB))
                        }
                    }                                  
                } else {
                    Write-Error "$($Path) is currently mounted. Dismount disk and try again."
                    return
                }

            }
        }          
    } 
    End { $results }
}
