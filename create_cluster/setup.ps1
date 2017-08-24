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

    InstanceFactory ($Name, $Backend, $BaseVHDsPath, $WorkingVHDsPath) {
        $this.Name = $Name
        $this.Backend = $Backend
        $this.BaseVHDsPath = $BaseVHDsPath
        $this.WorkingVHDsPath = $WorkingVHDsPath

        $this.CopyVHDFiles
        $this.GetVHDFiles
        $this.CreateInstances
    }

    [void] CopyVHDFiles () {
        $Files = Get-ChildItem -Path $this.BaseVHDsPath -Recurse -Filter *.vhd* | % {$_.FullName}

        foreach ($VHDFile in $Files) {
            Copy-Item -Path $VHDFile -Destination $this.WorkingVHDsPath
        }
    }

    [void] GetVHDFiles () {
        $this.VHDFiles = Get-ChildItem -Path $this.WorkingVHDsPath -Recurse -Filter *.vhd* | % {$_.FullName}
    }

    [void] CreateInstances () {
        foreach ($VHDFile in $this.VHDFiles) {
            $Random = Get-Random -Maximum 1000
            $Call = "$this.Name-$Random"
            $this.Instances += [HypervInstance]::new($Call, $this.Backend, $VHDFile)
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
        [String] $SecretsFile = "C:\Users\dimi\workspace\utils\build-cluster\create_cluster\secrets.ps1"
    )

    InstallPoshSSH
    InstallCassandraCSharpDriver $NugetInstallPath $NugetURL

    . $BackendFile
    . $CassandraClusterFile

    $Params = @("localhost", $SecretsFile)
    $Backend = [HypervBackend]::new($Params)

    $Factory = [InstanceFactory]::new("CBSLInstance", $Backend, $BaseVHDsPath, $WorkingVHDsPath)
    $Instances = $Factory.GetInstances()

    $Cluster = [CassandraCluster]::new("CBSLCassandraCluster", $SecretsFile, $NugetInstallPath, $CassandraInstallFile)
    $Cluster.CreateCluster()

}


Main
