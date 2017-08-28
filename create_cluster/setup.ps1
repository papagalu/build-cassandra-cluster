function InstallPoshSSH {
    Write-Host "Installing Posh-SSH..." -ForegroundColor Magenta
    Install-Module -Name Posh-SSH -Force  -WarningAction silentlyContinue
}

function InstallCassandraCSharpDriver {
    param(
        [String] $NugetInstallPath,
        [String] $NugetURL = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    )

    Write-Host "Downloading Nuget..." -ForegroundColor Magenta
    Invoke-WebRequest $NugetURL -OutFile "$NugetInstallPath\nuget.exe" | Out-Null
    Write-Host "Installing Cassandra C# Driver..." -ForegroundColor Magenta
    & "$NugetInstallPath\nuget.exe" install CassandraCSharpDriver -OutputDirectory $NugetInstallPath | Out-Null
}

class InstanceFactory {
    [String] $Name
    [Backend] $Backend
    [Array] $Instances
    [Array] $VHDFiles
    [String] $BaseVHDsPath
    [String] $WorkingVHDsPath
    [String] $DvdDrive

    InstanceFactory ($Name, $Backend, $BaseVHDsPath, $WorkingVHDsPath) {
        $this.Name = $Name
        $this.Backend = $Backend
        $this.BaseVHDsPath = $BaseVHDsPath
        $this.WorkingVHDsPath = $WorkingVHDsPath

        $this.MakeChild()
        $this.GetVHDFiles()
        $this.CreateInstances()
    }

    [void] MakeChild () {
        Write-Host "Making Child from Parent VHDs..." -ForegroundColor Magenta

        $Files = Get-ChildItem -Path $this.BaseVHDsPath -Recurse -Filter *.vhd* | % {$_.FullName}

        foreach ($VHDFile in $Files) {
            $Random = Get-Random -Maximum 1000
            $Path = $this.WorkingVHDsPath + "\$Random.vhdx" 
            New-VHD -ParentPath $VHDFile -Path $Path -Differencing
        }
    }

    [void] GetVHDFiles () {
        $this.VHDFiles = Get-ChildItem -Path $this.WorkingVHDsPath -Recurse -Filter *.vhd* | % {$_.FullName}
    }

    [void] CreateInstances () {
        Write-Host "Creating Instances..." -ForegroundColor Magenta

        foreach ($VHDFile in $this.VHDFiles) {
            $Random = Get-Random -Maximum 1000
            $Call = "Cassandra-$Random"
            $this.Instances += [HypervInstance]::new($this.Backend, $Call, $VHDFile)
        }
    }

    [Array] GetInstances () {
        return $this.Instances
    }
}

function Main () {
    param(
        [String] $BaseVHDsPath =  "C:\Users\dimi\workspace\utils\BaseVHDsPath",
        [String] $WorkingVHDsPath = "C:\Users\dimi\workspace\utils\WorkingVHDsPath",
        [String] $VMNamesDumpFile,
        [String] $BackendFile = "C:\Users\dimi\workspace\utils\build-cluster\create_cluster\backend.ps1",
        [String] $CassandraClusterFile = "C:\Users\dimi\workspace\utils\build-cluster\create_cluster\cassandra_cluster.ps1",
        [String] $CassandraInstallFile = "C:\Users\dimi\workspace\utils\build-cluster\create_cluster\installCassandra.sh",
        [String] $NugetInstallPath = "C:\Users\dimi\workspace\utils\NugetInstallPath",
        [String] $NugetURL =  "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe",
        [String] $BackendSecretsFile = "C:\Users\dimi\workspace\utils\build-cluster\create_cluster\secrets.ps1",
        [String] $GuestSecretsFile = "C:\Users\dimi\workspace\utils\build-cluster\create_cluster\secrets2.ps1"
    )

    InstallPoshSSH
    InstallCassandraCSharpDriver $NugetInstallPath $NugetURL

    . $BackendFile
    . $CassandraClusterFile

    $Params = @("localhost", $BackendSecretsFile)
    $Backend = [HypervBackend]::new($Params)

    $Factory = [InstanceFactory]::new("CBSLInstance", $Backend, $BaseVHDsPath, $WorkingVHDsPath)
    $Instances = $Factory.GetInstances()

    $Cluster = [CassandraCluster]::new("CBSLCassandraCluster", $GuestSecretsFile, $NugetInstallPath, $CassandraInstallFile)
    
    foreach ($Instance in $Instances) {
        $Cluster.AddInstance($Instance)
    }
    
    $Cluster.CreateCluster()
    
    # TODO(papagalu): save in a file for later use
    $Cluster.IPs

}


Main
