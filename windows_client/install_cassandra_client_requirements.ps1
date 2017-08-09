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

function InstallCassandraCSharpDriver() {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$settings
    )
    $nugetURL = $settings.Get_Item("nuget_URL")
    $nugetFolder = $settings.Get_Item("path_to_nuget")

    Invoke-WebRequest $nugetURL -OutFile $nugetFolder\nuget.exe
    & $nugetFolder\nuget.exe install CassandraCSharpDriver -OutputDirectory $nugetFolder
}

function Main() {
    $settings = Get-Config -configPath $configPath
    InstallCassandraCSharpDriver $settings
}

Main
