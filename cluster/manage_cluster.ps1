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

# not ready for use yet

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


function Start-Hyper-v() {
    foreach($vm in get-vm | where name -like Cassandra*) {
        start-vm $vm
    }
}

function Stop-Cluster() {
    foreach($vm in get-vm | where name -like Cassandra*) {
        stop-vm $vm
    }
}

function Start-Cluster() {
    Start-Hyper-v

    sleep 40

    do {
        sleep 10
        $ips=(Get-VM | where name -like cassandra* | Get-VMNetworkAdapter).ipAddresses | ?{$_ -notmatch ':'}
    } while($ips -eq $null);
    Get-SSHSessionToCluster
    for($i=0;$i -lt $ips.Length) {
        invoke-sshcommand -Index $i -command '/opt/cassandra/bin/cassandra -R'
    }
}

function Get-SSHSessionToCluster() {

    Get-SSHSession | remove-sshsession
    Get-SSHTrustedHost | remove-SSHTrustedHost

    $user = $settings.Get_Item("username")
    $password = $settings.Get_Item("password")

    $PWord = ConvertTo-SecureString -String $password -AsPlainText -Force
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $user, $PWord

    foreach($ip in $ips) {
        new-sshsession -computername $ip -Credential $Credential -AcceptKey
    }
}
