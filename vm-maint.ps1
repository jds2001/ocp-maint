[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $action
)

$clusterVMs = ("bootstrap", "master1", "master2", "master3", "worker1", "worker2")

function New-CustomVM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$vmName
    )

    process {
        $vm = New-VM -Name $vmName -NewVHDPath "E:\VM Files\$vmName.vhdx" -NewVHDSizeBytes 100GB -MemoryStartupBytes 8GB -BootDevice VHD -Generation 2 -SwitchName "private"
        Set-VM -VM $vm -ProcessorCount 4 -DynamicMemory  -MemoryMaximumBytes 16GB -MemoryMinimumBytes 4GB 
        Add-VMScsiController -VM $vm -Passthru
        $dvd = Add-VMDvdDrive -VM $vm -ControllerNumber 1 -Path "D:\downloads\rhcos-42.80.20190828.2-installer.iso" -Passthru
        Set-VMFirmware -VM $vm -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority" -FirstBootDevice $dvd
        # set  our custom MAC's so DHCP works and they get the right IP - this is a pretty bad hack
        switch ($vmName) {
            "master1" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:12" }
            "master2" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:13" }
            "master3" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:14" }
            "worker1" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:15" }
            "worker2" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:16" }
            "bootstrap" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:11" }
            Default {}
        }
        Start-VM -VM $vm
    }
}

function Set-VMBootOrderHD {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [String]$vmName
    )
    
    process {
        $vm = Get-VM -Name $vmName
        $drive = Get-VMHardDiskDrive -VM $vm
        Set-VMFirmware -FirstBootDevice $drive
    }
}

function Remove-PowerOffVM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][String]$vmName
    )
    process {
        $vm = Get-VM -VMName $vmName -ErrorAction SilentlyContinue
        if ($null -eq $vm) { Write-Output "vm $vmName doesnt exist" }
        elseif ($vm.State -eq "Running") {
            Stop-VM -VM $vm -TurnOff -Force
            Remove-VM -VM $vm -Force
            Remove-Item "E:\VM Files\$vmName*.*vhdx"
        }
        else {
            Remove-VM -VM $vm -Force
            Remove-Item "E:\VM Files\$vmName*.*vhdx"
        }     
    }    
}

switch ($action) {
    "create-cluster" { 
        $clusterVMs | ForEach-Object -Process { New-CustomVM -vmName $_ }
    }
    "create-test" {
        $vms = ("test-vm")
        $vms | ForEach-Object -Process { New-CustomVM -vmName $_ }
    }
    "delete-cluster" {
        $clusterVMs | ForEach-Object -Process { Remove-PowerOffVM -vmName $_ }
    }
    "delete-test" {
        $vms = ("test-vm")
        $vms | ForEach-Object -Process { Remove-PowerOffVM -vmName $_ }
    }
    "set-cluster-boot" {
        $clusterVMs | ForEach-Object -Process {
            Set-VMBootOrderHD -vmName $_
        }
    }
    "delete-bootstrap" { Remove-PowerOffVM -vmName "bootstrap" }
    Default { Write-Error "invalid choice" }
}