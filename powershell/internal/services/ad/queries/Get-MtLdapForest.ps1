function Get-MtLdapForest {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    function Resolve-FsmoOwner {
        param([string] $OwnerDistinguishedName)

        if ([string]::IsNullOrWhiteSpace($OwnerDistinguishedName)) { return $null }
        try {
            $serverDn = $OwnerDistinguishedName -replace '^CN=NTDS Settings,', ''
            $server = Invoke-MtLdapSearch -Connection $Connection -SearchBase $serverDn -Scope Base -Filter '(objectClass=server)' -Attributes @('dNSHostName') -PageSize 0 | Select-Object -First 1
            if (-not [string]::IsNullOrWhiteSpace($server.dNSHostName)) { return [string]$server.dNSHostName }
        }
        catch {
            Write-Verbose "Could not resolve FSMO owner '$OwnerDistinguishedName': $($_.Exception.Message)"
        }

        return $OwnerDistinguishedName
    }

    try {
        $rootDse = Get-MtLdapRootDse -Connection $Connection
        $attributes = @('distinguishedName', 'dnsRoot', 'nCName', 'nETBIOSName', 'systemFlags', 'trustParent')
        $partitions = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $ConfigurationNamingContext -Scope Subtree -Filter '(objectClass=crossRef)' -Attributes $attributes)
        $domainPartitions = @($partitions | Where-Object { $_.dnsRoot -and $_.nCName -like 'DC=*' })
        $rootPartition = $domainPartitions | Where-Object { $_.nCName -eq $rootDse.RootDomainNamingContext } | Select-Object -First 1
        $forestModeNames = @('Windows2000Forest', 'Windows2003InterimForest', 'Windows2003Forest', 'Windows2008Forest', 'Windows2008R2Forest', 'Windows2012Forest', 'Windows2012R2Forest', 'Windows2016Forest')
        $forestModeValue = [int]$rootDse.ForestFunctionality
        $fallbackRootDomain = (([regex]::Matches($rootDse.RootDomainNamingContext, '(?i)(?:^|,)DC=([^,]+)') | ForEach-Object { $_.Groups[1].Value }) -join '.')

        $crossForestReferences = @($partitions | Where-Object {
            $flags = if ($null -ne $_.systemFlags) { [int]$_.systemFlags } else { 0 }
            ($flags -band 0x2) -ne 0
        } | ForEach-Object {
            [PSCustomObject]@{
                DnsRoot    = [string]$_.dnsRoot
                NCName     = [string]$_.nCName
                NetBIOSName = [string]$_.nETBIOSName
            }
        })

        # Query forest-wide FSMO role holders and suffixes
        $schemaFsmo = Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Schema,$ConfigurationNamingContext" -Scope Base -Filter '(objectClass=*)' -Attributes @('fSMORoleOwner') -PageSize 0 | Select-Object -First 1
        $partitionsContainer = Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Partitions,$ConfigurationNamingContext" -Scope Base -Filter '(objectClass=*)' -Attributes @('fSMORoleOwner', 'uPNSuffixes', 'msDS-SPNSuffixes') -PageSize 0 | Select-Object -First 1

        return [PSCustomObject]@{
            RootDomain           = if ($null -ne $rootPartition) { [string]$rootPartition.dnsRoot } else { $fallbackRootDomain }
            Domains              = [string[]]@($domainPartitions | ForEach-Object { $_.dnsRoot } | Sort-Object -Unique)
            ForestMode           = if ($forestModeValue -ge 0 -and $forestModeValue -lt $forestModeNames.Count) { $forestModeNames[$forestModeValue] } else { $forestModeValue }
            SchemaMaster         = Resolve-FsmoOwner -OwnerDistinguishedName ([string]$schemaFsmo.fSMORoleOwner)
            DomainNamingMaster   = Resolve-FsmoOwner -OwnerDistinguishedName ([string]$partitionsContainer.fSMORoleOwner)
            UPNSuffixes          = [string[]]@(@($partitionsContainer.uPNSuffixes) | Where-Object { $null -ne $_ })
            SPNSuffixes          = [string[]]@(@($partitionsContainer.'msDS-SPNSuffixes') | Where-Object { $null -ne $_ })
            CrossForestReferences = $crossForestReferences
        }
    }
    catch {
        Write-Verbose "Could not query LDAP forest information: $($_.Exception.Message)"
        return $null
    }
}
