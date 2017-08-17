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

<#
.SYNOPSIS
    .
.DESCRIPTION
    Script that loads the CassandraCShaprpDriver and returns a client to a
    cluster
.PARAMETER IPs
    Array of Strings which contians the IPs of the Cassandra Cluster
.PARAMETER keyspace
    Name of the keyspace the cassandra client connects to
    It has to be created before running this script
.EXAMPLE
    C:\PS>$client = <script> -IPs @("ip1", "ip2",...) -keyspace "your_keyspace"
    C:\PS>$client.executeQuery("SELECT * FROM <your_table>;")
.NOTES
    .
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$configPath,

    [Parameter(Mandatory=$true)]
    [string[]]$IPs,

    [Parameter(Mandatory=$true)]
    [string]$keyspace
)

$ErrorActionPreferance = "stop"

function Get-Config {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configPath
    )
    Get-Content "$configPath" | ForEach-Object -Begin {$settings=@{}} -Process `
        { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and `
        ($k[0].StartsWith("[") -ne $True)) { $settings.Add($k[0], $k[1]) } }
    return $settings
}

function Get-BlacklistedDLLs {
    <#
    .SYNOPSIS
    These DLLs are mot required and fail to load so we blacklist them.
    #>
    $doNotLoad = @("$baseFolder\System.Linq.4.1.0\ref\netstandard1.6\System.Linq.dll",
                    "$baseFolder\System.Linq.Expressions.4.1.0\ref\netstandard1.6\System.Linq.Expressions.dll",
                    "$baseFolder\System.Reflection.4.1.0\ref\netstandard1.5\System.Reflection.dll",
                    "$baseFolder\System.Runtime.4.1.0\ref\netstandard1.5\System.Runtime.dll",
                    "$baseFolder\System.Runtime.Extensions.4.1.0\ref\netstandard1.5\System.Runtime.Extensions.dll",
                    "$baseFolder\System.Runtime.InteropServices.4.1.0\ref\netstandard1.5\System.Runtime.InteropServices.dll"
    )
    return $doNotLoad
}

function Load-CassandraCSharpDriver {
    $DLLs = Get-ChildItem -Path $baseFolder -Filter "*.dll" -Recurse `
        -ErrorAction SilentlyContinue -Force | % { $_.FullName }

    $blacklist = Get-BlacklistedDLLs

    $DLLs = Compare-Object -DifferenceObject $DLLs -ReferenceObject $doNotLoad -PassThru
    $DLLs | ForEachObject {Add-Type -Path $_ -ErrorAction SilentlyContinue}
}

$settings = Get-Config -configPath $configPath
$baseFolder = $settings["path_to_nuget"]

Load-CassandraCSharpDriver

$builder = [Cassandra.Cluster]::Builder()

$IPs | ForEach-Object {$builder.AddContactPoint($_)}

$cluster = $builder.Build()
$session = $cluster.Connect($keyspace)

return $session

