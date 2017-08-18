# Copyright 2017 Cloudbase Solutions Srl
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

param(
    [Parameter(Mandatory=$true)]
    [string]$configPath
)

function Get-Config {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configPath
    )

    Get-Content $configPath | ForEach-Object -Begin {$settings=@{}} -Process `
        { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and `
        ($k[0].StartsWith("[") -ne $True)) { $settings.Add($k[0], $k[1]) } }
    return $settings
}

#creates childs from parent vhdx for each machine
function CreateChild {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$settings
    )

    for($i=0; $i -lt $settings["number_of_machines"]; $i++) {
        $path = $settings["path_to_vhd"] + "\Cassandra-node-$i.vhdx"
        New-VHD -Path $path -ParentPath `
	    $settings["path_to_parent"] -differencing
    }
}

#creates VMs, and attaches the configdrive
function CreateCluster {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$settings
    )

    CreateChild $settings

    $memory =  $settings["memory_per_machine"]
    $path_to_vhd = $settings["path_to_vhd"] 
    for($i=0; $i -lt $settings["number_of_machines"]; $i++) {
        
        $path_to_vhd_i = "$path_to_vhd\Cassandra-node-$i.vhdx"

        New-VM -Name "Cassandra-Node-$i" -VHDPath $path_to_vhd_i `
            -SwitchName external
        Set-VMMemory -DynamicMemoryEnabled $false -StartupBytes $memory
    }

    if($settings.Contains("path_to_configdrive")){
        $path_to_configdrive = $settings["path_to_configdrive"]
        for($i=0; $i -lt $settings["number_of_machines"]; $i++) {
            $path_to_configdrive_i = "$path_to_configdrive\config_drive$i.iso"
            Set-VMDvdDrive -VMName "Cassandra-node-$i" 
                -Path $path_to_configdrive_i
            }
    }
}

function StartHyper-v() {
    Get-VM | ForEach-Object { where name -like Cassandra* | Start-VM $_}
}

function Main() {
    $settings = Get-Config $configPath
    CreateCluster $settings
    StartHyper-v
}

Main

