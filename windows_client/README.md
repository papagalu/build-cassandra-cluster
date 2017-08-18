#### Getting a Cassandra Client

Requirements:
* A running Cassandra cluster
* A keyspace in the cluster

```
install_cassandra_client_requirements.ps1 ` 
    -nugetURL https://dist.nuget.org/win-x86-commandline/latest/nuget.exe `
    -installPath <somePath>

# string array of ips of your cluster
$IPs = @("ip1", "ip2", ...)

$client = cqlsh.ps1 -IPs $IPs -keyspace "<your keyspace>"

# and now we can execute queries like so:
$client.Execute("SELECT * FROM <your_table>;")
```

