# build-cassandra-cluster

Small set of PowerShell scripts that spins up a Cassandra Cluster in Hyper-V(local only).

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Installing

A step by step series of examples that tell you have to get a development env running.

* Clone the repo.
* change the settings-vm.conf file to match your env.
* run deploy_cluster

After this step you should be having a Cassandra Cluster up and running.
To connect to it you have to do the following:

* run setup
* get a client from cqlsh and start using it

#### Getting a Cassandra Client

Requirements:
* A running Cassandra cluster
* A keyspace in the cluster

```
install_cassandra_client_requirements.ps1
$IPs = @("ip1", "ip2", ...)
$client = cqlsh.ps1 -IPs $IPs -keyspace "<your keyspace>"
# and now we can execute queries like so:
$client.Execute("SELECT * FROM <youR_table>;")
```
