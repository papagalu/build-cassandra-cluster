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

# Quick and dirty just to make some basic configdrive for local testing

param(
    [Parameter(Mandatory=$true)]
    [string]$configPath
)

function Get-Config() {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configPath
    )
    Get-Content "$configPath" | foreach-object -begin {$settings=@{}} -process `
        { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and `
        ($k[0].StartsWith("[") -ne $True)) { $settings.Add($k[0], $k[1]) } }
    return $settings
}

function Make-ISO ([string]$target_path, [string]$output_path, [string]$mkisofs_path){
    & $mkisofs_path -r -R -J -l -L -o  $output_path $target_path
}

function Alter-Configdrive([hashtable]$settings, [int32]$number) {
    $target_path=$settings.Get_Item("path_to_target_configdrive")

    Copy-Item -Recurse $target_path "$target_path$number"
    $target_path="$target_path$number"

    $meta_data_files_ec2=Get-ChildItem -Path $target_path -Filter meta-data.json -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }
    $meta_data_files_openstack=Get-ChildItem -Path $target_path -Filter meta_data.json -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }
    $user_data_ec2=Get-ChildItem -Path $target_path -Filter user_data -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }
    $user_data_openstack=Get-ChildItem -Path $target_path -Filter user-data -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }

    $settings.Get_Item("user_data")

    foreach($file in $user_data_ec2) {
        cp $settings.Get_Item("user_data") $file
    }

    foreach($file in $user_data_openstack) {
        cp $settings.Get_Item("user_data") $file
    }

    #TODO(papagalu): if i change files like this cloud-init won't see the configdrive anymore
    #                i have to investigate more

    #foreach($file in $meta_data_files_ec2) {
    #    $json_format=cat $file | ConvertFrom-json
    #    $json_format.hostname=$settings.Get_Item("hostname") + $number
    #    $json_format."public-keys"=$settings.Get_Item("public_keys")
    #    $json_format | ConvertTo-Json -compress | Out-File -force $file
    #}

    #foreach($file in $meta_data_files_openstack) {
    #    $json_format=cat $file | ConvertFrom-json
    #    $json_format.hostname=$settings.Get_Item("hostname") + $number
    #    $json_format.name=$settings.Get_Item("hostname") + $number
    #    $json_format.keys=$settings.Get_Item("keys")
    #    $json_format."public_keys"=$settings.Get_Item("public_keys")
    #    $json_format | ConvertTo-Json -compress | Out-File -force $file
    #}

    $output=$settings.Get_Item("path_to_configdrive") + "/config-drive" + $number + ".iso"
    Make-ISO -target_path $target_path -output_path $output -mkisofs_path `
        $settings.Get_Item("path_to_mkisofs")
    rm -Force -Recurse $target_path
}

function Main() {
    $settings=Get-Config $configPath

    for ($i=0; $i -lt $settings.Get_Item("number_of_machines"); $i++) {
        Alter-Configdrive -settings $settings -number $i
    }
}

Main
