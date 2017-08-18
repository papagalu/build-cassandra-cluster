#### Installing Cassandra and configuring the cluster

The purpose of this script is to take an array of host with username/password
and install Cassandra on them, and configure each host to be part of the same
cluster


Requirements:
* PowerShell at least 5.1
* Posh-SSH installed ```Install-Module -Name Posh-SSH```
* Ubuntu 16.04 with ssh configured(for hosts)

```
.\cluster\deploy_cassandra_cluster.ps1 -IPs $IPs -username $username `
    -password $password -installFile $installFile
```
