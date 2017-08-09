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

function Get-IPs() {
    $ips=(Get-VM | where name -like cassandra* | Get-VMNetworkAdapter).ipAddresses | ?{$_ -notmatch ':'}

    do {
        sleep 30
        $ips=(Get-VM | where name -like cassandra* | Get-VMNetworkAdapter).ipAddresses | ?{$_ -notmatch ':'}
    } while($ips -eq $null);
    return $ips
}

function Get-SSHSessionToCluster() {

    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$settings,

        [Parameter(Mandatory=$true)]
        $ips
    )

    Get-SSHSession | Remove-SSHSession
    Get-SSHTrustedHost | Remove-SSHTrustedHost

    $user = $settings.Get_Item("username")
    $password = $settings.Get_Item("password")

    $PWord = ConvertTo-SecureString -String $password -AsPlainText -Force
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $user, $PWord

    foreach($ip in $ips) {
        new-sshsession -computername $ip -Credential $Credential -AcceptKey
    }
}


function Get-Seeds() {
    param(
        [Parameter(Mandatory=$true)]
        $ips
    )

    $b=$ips -join ', '
    $seeds='"' + $b + '"'
    return $seeds
}

function Reboot-Cluster() {
    param(
        [Parameter(Mandatory=$true)]
        $number_of_machines
    )

    for($i=0; $i -lt $number_of_machines; $i++) {
        invoke-sshcommand -Index $i -command 'reboot' -TimeOut -ErrorAction SilentlyContinue
    }
    sleep 40
}

function Configure-Cluster() {
    param(
        [Parameter(Mandatory=$true)]
        $number_of_machines,

        [Parameter(Mandatory=$true)]
        [string]$seeds
    )

    for($i=0; $i -lt $number_of_machines; $i++) {
        invoke-sshcommand -Index $i -command "echo $(hostname -I) $(hostname) >> /etc/hosts"
        invoke-sshcommand -Index $i -command 'sed -i "10s/.*/cluster_name: \"CloudBaseCluster\"/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -Index $i -command 'sed -i "948s/.*/endpoint_snitch: GossipingPropertyFileSnitch/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -Index $i -command 'sed -i "675s/.*/rpc_address: $(hostname -I)/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -Index $i -command 'sed -i "598s/.*/listen_address: $(hostname -I)/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -Index $i -command "sed -i `"424s/.*/                - seeds: `"$seeds`"/`" /opt/cassandra/conf/cassandra.yaml"
        invoke-sshcommand -Index $i -command '/opt/cassandra/bin/cassandra -R'
    }
}

function Main() {

    $settings = Get-Config $configPath

    & $PSScriptRoot\generate-configdrives.ps1 -configPath $configPath
    & $PSScriptRoot\create_hyper-v_cluster.ps1 -configPath $configPath

    sleep 260

    $ips = Get-IPs
    $seeds = Get-Seeds $ips

    Get-SSHSessionToCluster -settings $settings  $ips

    Reboot-Cluster $ips.Length
    Configure-Cluster -number_of_machines $ips.Length -seeds $seeds
}

Main
