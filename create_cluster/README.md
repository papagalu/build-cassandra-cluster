#### Creating cluster

The purpose of this script is to create a set of machines from a set of VHD files.
Install Cassandra and configure a Cassandra cluster on them.

Requirements:
* Windows 10/2016
* Hyper-v enabled
* Parent vhdx

```
$BaseVHDsPath = folder where you should put Parent VHDs
$WorkingVHDsPath = folder where the Children will be stored
$VMNamesDumpFile // not used
$BackendFile = path to the backend class file
$CassandraClusterFile = path to the Cassandra class file
$CassandraInstallFile = sh script that will be copied on the children and executed
$NugetInstallPath = folder of the nuget install and Cassandra C# driver, (should be empty, downloads tons of stuff)
$NugetURL = URL to nuget.exe download
$BackendSecretsFile = secret file with creds for the backend $global:usernmae  = <username> $global:password = <password>
$GuestSecretsFile = secret file with creds for the children ---//----
```

After setting everything up:

```
. $backendFile
. \path\to\setup.ps1
```

Tested with Windows 10 Host and Ubuntu 16.04 guests

### NOTE: LIS drivers, LIS KVP daemon should be installed on the VM

We fetch the ip from Hyper-V
