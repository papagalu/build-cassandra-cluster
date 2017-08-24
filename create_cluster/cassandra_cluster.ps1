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

class CassandraCluster {
    [String] $Name
    [Array] $Instances = @()
    [Array] $SSHSessions = @()
    [Array] $IPs = @()
    [String] $NugetInstallPath
    [String] $CassandraInstallFile
    [String] $Seeds = ""
    [String] $SecretsPath 
    [System.Management.Automation.PSCredential] $Credentials

    CassandraCluster ($Name, $SecretsPath, $NugetInstallPath, $CassandraInstallFile) {
        $this.Name = $Name
        $this.SecretsPath = $SecretsPath
        $this.NugetInstallPath = $NugetInstallPath
        $this.CassandraInstallFile = $CassandraInstallFile

         if (Test-Path $this.SecretsPath) {
            $this.GetCredentials()
        } else {
            throw "??? Credential file does not exist"
        }
    }

    [void] GetCredentials() {
        . $this.SecretsPath
        $securePassword = ConvertTo-SecureString -AsPlainText -Force $global:password
        $this.Credentials = New-Object System.Management.Automation.PSCredential `
            -ArgumentList $global:username, $securePassword
    }

    
    [void] AddInstance ($Instance) {
        $this.Instances += $Instance
    }

    [void] GetIPs () {
        $this.IPs = @()

        ForEach ($Instance in $this.Instances) {
            $this.IPs += $Instance.GetPublicIP()
        }
    }

    [void] GetSSHSessions () {
        $this.SSHSessions = $()

        ForEach ($ip in $this.IPs) {
            $this.SSHSessions += New-SSHSession `
                                    -ComputerName $ip `
                                    -Credential $this.Credentials `
                                    -AcceptKey
        }
    }

    [void] CreateCluster() {
        Write-Host "Starting creation of the Cassandra Cluster" -ForegroundColor Magenta
        ForEach ($Instance in $this.Instances) {
            $Instance.CreateInstance()
        }

        $this.GetIPs()
        $this.GetSSHSessions()
        $this.InstallCluster()
        $this.ConfigureCluster()
        $this.StartCassandra()

    }

    [void] InstallCluster () {
        Write-Host "Installing the Cassandra Cluster" -ForegroundColor Magenta
        
        (Get-Content -Raw -Path $this.CassandraInstallFile) | % { $_ -replace "`r`n","`n"} | `
            Set-Content -Path $this.CassandraInstallFile
        
        $basename=(Get-Item $this.CassandraInstallFile).Name
 
        ForEach ($ip in $this.IPs) {
            #NOTE(papagalu): File should be in unix format otherwise we can't
            #                run it
            Set-SCPFile -LocalFile $this.CassandraInstallFile `
                        -RemotePath "/root" `
                        -ComputerName $ip `
                        -Credential $this.Credentials
                        -AcceptKey $true
        }

        ForEach ($SSHSession in $this.SSHSessions) {
            Invoke-SShCommand -SSHSession $SSHSession 
                              -Command "chmod +x /root/$basename"
            Invoke-SSHCommand -SSHSession $SSHSession
                              -Command "/root/$basename"
        }
    }

    [void] GetSeeds () {
        $s = ""
        
        $b = $this.IPs -join ', '
        $s = '"' + $b + '"'

        $this.Seeds = $s
   }

    [void] ConfigureCluster() {
        Write-Host "Configuring the Cassandra Cluster" -ForegroundColor Magenta

        $this.GetSeeds()

        ForEach ($SSHSession in $this.SSHSessions) {
        Invoke-SSHCommand -SSHSession $SSHSession `
                          -Command "echo $(hostname -I) $(hostname) >> /etc/hosts"
        Invoke-SSHCommand -SSHSession $SSHSession `
                          -Command 'sed -i "10s/.*/cluster_name: \"CloudBaseCluster\"/" /opt/cassandra/conf/cassandra.yaml'
        Invoke-SSHCommand -SSHSession $SSHSession `
                          -Command 'sed -i "948s/.*/endpoint_snitch: GossipingPropertyFileSnitch/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -SSHSession $SSHSession `
                          -Command 'sed -i "675s/.*/rpc_address: $(hostname -I)/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -SSHSession $SSHSession `
                          -Command 'sed -i "598s/.*/listen_address: $(hostname -I)/" /opt/cassandra/conf/cassandra.yaml'
        invoke-sshcommand -SSHSession $SSHSession `
                          -Command "sed -i `"424s/.*/                - seeds: `"$this.seeds`"/`" /opt/cassandra/conf/cassandra.yaml"
        }
    }

    [void] StartCassandra () {
         ForEach ($SSHSession in $this.SSHSessions) {
             Invoke-SShCommand -SSHSession $SSHSession -Command "/opt/cassandra/bin/cassandra -R"
        }
    }

    [void] StartCluster() {
        Write-Host "Starting the Cassandra Cluster" -ForegroundColor Magenta
        ForEach ($Instance in $this.Instances) {
            $Instance.StartInstance()
        }
        $this.StartCassandra()
    }

    [void] StopCluster() {
        Write-Host "Stoping the Cassandra Cluster" -ForegroundColor Magenta
        ForEach ($Instance in $this.Instances) {
            $Instance.StopInstance()
        }
    }

    [void] RestartCluster () {
        Write-Host "Restarting the Cassandra Cluster" -ForegroundColor Magenta
        $this.StopCluster()
        $this.StartCluster()
    }

    [void] RemoveCluster () {
        Write-Host "Removing the Cassandra Cluster" -ForegroundColor Magenta
        ForEach ($Instance in $this.Instances) {
            $Instance.StopInstance()
            $Instance.RemoveInstance()
        }
    }

    [void] GetCQLSHSession () {

    }
}
