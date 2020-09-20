[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $action
)

$clusterVMs = ("bootstrap", "master1", "master2", "master3", "worker1", "worker2")
$externalClusterVMs = ("bootstrap-external", "master1-external", "master2-external", "master3-external", "worker1-external", "worker2-external" )

function New-CustomVM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$vmName,
        [String]$switchName
    )

    process {
        $vm = New-VM -Name $vmName -NewVHDPath "E:\VM Files\$vmName.vhdx" -NewVHDSizeBytes 100GB -MemoryStartupBytes 8GB -BootDevice VHD -Generation 2 -SwitchName $switchName
        Set-VM -VM $vm -ProcessorCount 4 -DynamicMemory  -MemoryMaximumBytes 16GB -MemoryMinimumBytes 4GB 
        Add-VMScsiController -VM $vm -Passthru
        $dvd = Add-VMDvdDrive -VM $vm -ControllerNumber 1 -Path "D:\Downloads\rhcos-4.6.0-0.nightly-2020-09-10-195619-x86_64-live.x86_64.iso" -Passthru
        Set-VMFirmware -VM $vm -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority" -FirstBootDevice $dvd
        # set  our custom MAC's so DHCP works and they get the right IP - this is a pretty bad hack
        switch ($vmName) {
            "master1" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:12" }
            "master2" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:13" }
            "master3" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:14" }
            "worker1" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:15" }
            "worker2" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:16" }
            "master1-external" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:17" }
            "master2-external" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:18" }
            "master3-external" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:19" }
            "worker1-external" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:1A" }
            "worker2-external" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:1B" }
            "bootstrap-external" { Set-VMNetworkAdapter -VM $vm -StaticMacAddress "00:15:5D:B7:25:1C" }
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
        Set-VMFirmware -VM $vm -FirstBootDevice $drive
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
        $clusterVMs | ForEach-Object -Process { New-CustomVM -vmName $_ -switchName "private"}
    }
    "create-external-cluster" {
        $externalClusterVMs | ForEach-Object -Process { New-CustomVM -vmName $_ -switchName "external vswitch" }
    }
    "create-test" {
        $vms = ("test-vm")
        $vms | ForEach-Object -Process { New-CustomVM -vmName $_ -switchName "private"}
    }
    "delete-cluster" {
        $clusterVMs | ForEach-Object -Process { Remove-PowerOffVM -vmName $_ }
    }
    "delete-external-cluster" {
        $externalClusterVMs | ForEach-Object -Process { Remove-PowerOffVM -vmName $_ }
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
    "set-external-cluster-boot" {
        $externalClusterVMs | ForEach-Object -Process { Set-VMBootOrderHD -vmName $_ }
    }
    "delete-bootstrap" { Remove-PowerOffVM -vmName "bootstrap" }
    "delete-external-bootstrap" { Remove-PowerOffVM -vmName "bootstrap-external "}
    Default { Write-Error "invalid choice" }
}