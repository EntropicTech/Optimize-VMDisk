function Optimize-VMDisk
{
    <#
        .SYNOPSIS
            This is a cmdlet that will mount, optimize and dismount a VM's disks.

        .DESCRIPTION
            This cmdlet verifies that a VM is turned off, disks are unmounted and that it has no checkpoints.
            If the VM meets all of these requirements it mounts the VM's disks read only and then performs Optimize-VHD on the VM's disks and then dismounts the disk.

        .PARAMETER Name
            This is the name of the VM that you want optimized. Accepts pipeline input from Get-VM.

        .PARAMETER Shutdown
            If used, this will perform Stop-VM -Force on all of the VMs selected to be optimized. The VM's will be started again once the script completes.
    
        .INPUTS
            Accepts pipeline input from Get-VM.

        .OUTPUTS
            Outputs a PSObject with the results of the optimization process. 
        
        .EXAMPLE
            Optimize-VMDisk -Name ET-DC-02 -Shutdown 
    #>    
    [CmdletBinding()]
    Param(
            [parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
            [ValidateNotNullorEmpty()]
            [string[]]
            $Name,
            
            [parameter(Mandatory=$False)]
            [switch]
            $Shutdown
    )
    
    Begin
    {
    
    # Checks to see if it is being run in an administrative prompt. Breaks the script if not.
    if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544') -eq $False )
    {  
        Write-Error 'This script must be run with administrator privledges. Relaunch script in an administrative prompt.'
        break
    }

    # Variable Setup
    $result = [System.Collections.ArrayList]@()
    }   
    
    Process
    {

        foreach ($vmname in $Name)
        {

            # Collect the VMs we are working with.
            try
            {
                Write-Verbose "Gathering information for $($vmname)."
                $VM = Get-VM -Name $vmname
                Write-Verbose "Found information for $($VM.Name)."
            }
            catch
            {
                Write-Verbose "Get-VM failed for $($VM.Name)."
                Write-Host $_.Exception.Message -ForegroundColor Red             
            }
            
            # Shutsdown the VM before attempting the optimization process.
            if ($Shutdown)
            {               
                $VMStateBeforeShutdown = $VM.State
                if ($VMStateBeforeShutdown -eq 'Running')
                {
                    try
                    {
                        Write-Verbose "Attempting to shutdown $($VM.Name)."
                        Stop-VM -Name $VM.Name -Force -Verbose
                    }
                    catch
                    {
                        Write-Verbose "Shutdown unsuccessful $($VM.Name)."
                        Write-Host $_.Exception.Message -ForegroundColor Red 
                    }                
                }               
            }
                        
            # Build variable of the disks connected to this VM.
            Write-Verbose "Gathering VM disk info from $($VM.Name)."
            $VMDisks = Get-VMHardDiskDrive -VMName $VM.Name
            
            # Validate that VM is not running, has no checkpoints and isn't mounted. If all pass then mount,optimize and dismount the disk.
            Write-Verbose "Verifying that $($VM.Name) is turned off."
            if ($VM.State -ne "Off" )
            {
                Write-Warning "$($VM.Name) is not turned off. Turn $($VM.Name) off and try again."
                continue
            }
            else
            {
                Write-Verbose "$($VM.Name) is turned off."            
                $result += foreach ($disk in $VMDisks)
                {
                    $Path = $disk.Path
                    $VHD = Get-VHD -Path $Path
                    $AttachCheck = $VHD.Attached
                    Write-Verbose "Verifying virtual disk is ready."
                    Write-Verbose "Verifying that $($Path) isn't mounted."
                    if ($AttachCheck -eq $False)
                    {
                        Write-Verbose "$($Path) is not mounted."
                        if ($Path.Split(".")[1] -eq 'avhdx')
                        {
                            Write-Warning "$($_.VMName) has a checkpoint. Merge the checkpoint and try again."
                            continue
                        }
                        else
                        {                         
                            Write-Verbose "Virtual disk state verified."
                            
                            # Mount the VHD
                            try
                            { 
                                Write-Verbose "Mounting $Path as read only."
                                Mount-VHD -Path $Path -ReadOnly
                            }
                            catch
                            {
                                Write-Host "Couldn't mount $($Path)" -ForegroundColor Red
                                Write-Host $_.Exception.Message -ForegroundColor Red
                            }
                            
                            # Optimize the VHD
                            try
                            {
                                $VHDSizePre = [math]::Round($VHD.FileSize /1GB)
                                Write-Verbose "Optimizing $Path." 
                                Optimize-VHD -Path $Path
                                $VHDSizePost = [math]::Round( (Get-VHD -Path $Path).FileSize /1GB )
                                $VHDSavings = $VHDSizePre - $VHDSizePost
                                Write-Verbose "Saved $VHDSavings GB."   
                            }
                            catch
                            {
                                Write-Host "Couldn't optimize $($Path)" -ForegroundColor Red
                                Write-Host $_.Exception.Message -ForegroundColor Red                        
                            }
                            
                            # Dismount the VHD
                            try
                            {
                                Write-Verbose "Dismounting $Path."
                                Dismount-VHD -Path $Path
                                Write-Verbose "$Path has been optimized."
                            }
                            catch
                            {
                                Write-Host "Couldn't dismount. $($Path)" -ForegroundColor Red
                                Write-Host $_.Exception.Message -ForegroundColor Red                        
                            }
                            [PSCustomObject]@{
                                VMName = $VM.Name
                                Disk = $Path
                                'Original(GB)' = $VHDSizePre
                                'Current(GB)' = $VHDSizePost
                                'Savings(GB)' = $VHDSavings                                                                                
                            }
                        }                                                     
                    }
                    else
                    {
                        Write-Error "$($Path) is currently mounted. Dismount disk and try again."
                        continue
                    }
                }
                
                # If the VM was turned off then turn it back on
                if ($VMStateBeforeShutdown -eq 'Running')
                {  
                    try
                    {
                        Write-Verbose "Attempting to Start $($VM.Name)."
                        Start-VM -Name $VM.Name -Verbose
                    }
                    catch
                    {
                        Write-Host "Couldn't start $($VM.Name)" -ForegroundColor Red
                        Write-Host $_.Exception.Message -ForegroundColor Red    
                    }
                }  
            }
        }
    }
    
    End
    {
        # Return report of how much space was reclaimed.
        $result
    }
}
