function Get-MtLdapForest {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    try {
        $rootDse = Get-MtLdapRootDse -Connection $Connection
        $attributes = @('distinguishedName', 'dnsRoot', 'nCName', 'nETBIOSName', 'systemFlags', 'trustParent')
        $partitions = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $ConfigurationNamingContext -Scope Subtree -Filter '(objectClass=crossRef)' -Attributes $attributes)
        $domainPartitions = @($partitions | Where-Object { $_.dnsRoot -and $_.nCName -like 'DC=*' })
        $rootPartition = $domainPartitions | Where-Object { $_.nCName -eq $rootDse.RootDomainNamingContext } | Select-Object -First 1
        $forestModeNames = @('Windows2000Forest', 'Windows2003InterimForest', 'Windows2003Forest', 'Windows2008Forest', 'Windows2008R2Forest', 'Windows2012Forest', 'Windows2012R2Forest', 'Windows2016Forest')
        $forestModeValue = [int]$rootDse.ForestFunctionality
        $fallbackRootDomain = (([regex]::Matches($rootDse.RootDomainNamingContext, '(?i)(?:^|,)DC=([^,]+)') | ForEach-Object { $_.Groups[1].Value }) -join '.')

        return [PSCustomObject]@{
            RootDomain = if ($null -ne $rootPartition) { [string]$rootPartition.dnsRoot } else { $fallbackRootDomain }
            Domains    = [string[]]@($domainPartitions | ForEach-Object { $_.dnsRoot } | Sort-Object -Unique)
            ForestMode = if ($forestModeValue -ge 0 -and $forestModeValue -lt $forestModeNames.Count) { $forestModeNames[$forestModeValue] } else { $forestModeValue }
        }
    }
    catch {
        Write-Verbose "Could not query LDAP forest information: $($_.Exception.Message)"
        return $null
    }
}
