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
    [string[]]$IPs,

    [Parameter(Mandatory=$true)]
    [string]$username,

    [Parameter(Mandatory=$true)]
    [string]$password,

    [Parameter(Mandatory=$true)]
    [string]$installFile,

    [string]$remoteLocation = "/root"
)

function Get-SSHSessionToCluster {

    param(
        [Parameter(Mandatory=$true)]
        [string[]]$IPs,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    Get-SSHSession | Remove-SSHSession
    Get-SFTPSession | Remove-SFTPSession
    Get-SSHTrustedHost | Remove-SSHTrustedHost

    foreach($ip in $IPs) {
        New-sshsession -computername $ip -Credential $credential -AcceptKey
    }
}

function Install-Cassandra {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$IPs,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory=$true)]
        [string]$installFile,

        [string]$remoteLocation = "/root"
    )

    (Get-Content -Raw -Path $installFile) | % { $_ -replace "`r`n","`n"} | `
        Set-Content -Path $installFile
    $basename=(Get-Item $installFile ).Basename

    ForEach($ip in $IPs) {
        Set-SCPFile -LocalFile $installFile -RemotePath $remoteLocation `
            -ComputerName $ip -Credential $credential -AcceptKey $true
    }

    For($i = 0; $i -lt $IPs.Length; $i++) {
        invoke-sshcommand -Index $i -Command "chmod +x $remoteLocation/$basename.sh"
        invoke-sshcommand -Index $i -Command "$remoteLocation/$basename.sh"
    }
}

function Configure-Cassandra {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$IPs,

        [Parameter(Mandatory=$true)]
        [string]$seeds
    )

    for($i=0; $i -lt $IPs.Length; $i++) {
        invoke-sshcommand -Index $i -command "echo $(hostname -I) $(hostname) >> /etc/hosts"
        invoke-sshcommand -Index $i -command 'sed -i "10s/.*/cluster_name: \"CloudBaseCluster\"/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -Index $i -command 'sed -i "948s/.*/endpoint_snitch: GossipingPropertyFileSnitch/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -Index $i -command 'sed -i "675s/.*/rpc_address: $(hostname -I)/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -Index $i -command 'sed -i "598s/.*/listen_address: $(hostname -I)/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -Index $i -command "sed -i `"424s/.*/                - seeds: `"$seeds`"/`" /opt/cassandra/conf/cassandra.yaml"
    }

}

function Get-Seeds() {
    param(
        [Parameter(Mandatory=$true)]
        $IPs
    )

    $b = $IPs -join ', '
    $seeds = '"' + $b + '"'

    return $seeds
}


function Start-Cassandra {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$IPs
    )

    For($i = 0; $i = $IPs.Length; $i++) {
        invoke-sshcommand -Index $i -command "/opt/cassandra/bin/cassandra -R"
    }
}

function Main {

    $pWord = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object -TypeName `
        "System.Management.Automation.PSCredential" `
        -ArgumentList $username, $pWord

   
    Get-SSHSessionToCluster -IPs $IPs -credential $credential

    Install-Cassandra -IPs $IPs -credential $credential `
        -installFile $installFile -remoteLocation $remoteLocation
    
    $seeds = Get-Seeds -IPs $IPs
    Configure-Cassandra -IPs $IPs -seeds $seeds

    Start-Cassandra -IPs $IPs
}

# Main
