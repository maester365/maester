function Get-MtLdapReplicationPartitionState {
    <#
    .SYNOPSIS
        Collects advertised and readable Active Directory naming-context posture.
    .DESCRIPTION
        Reads RootDSE namingContexts and performs one bounded base-scope LDAP read against each
        advertised naming context. Successful empty partner results are deliberately outside this
        helper's scope; replication-neighbor metadata requires a separate protocol implementation.
    .NOTES
        Author: Mario Contestabile
        LinkedIn: https://www.linkedin.com/in/mario-contestabile/
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Connection,
        [Parameter(Mandatory)]
        [PSCustomObject]$RootDse
    )

    $advertised = [string[]]@($RootDse.NamingContexts | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)
    $expected = [System.Collections.Generic.List[string]]::new()
    foreach ($value in @($RootDse.DefaultNamingContext,$RootDse.ConfigurationNamingContext,$RootDse.SchemaNamingContext)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) { $expected.Add([string]$value) | Out-Null }
    }
    # DNS application partitions do not replicate to every domain controller. Keep them observable,
    # but do not make their absence a core-partition failure for a DC that does not advertise them.
    $dnsApplicationPartitions = [System.Collections.Generic.List[object]]::new()
    foreach ($definition in @(
        [PSCustomObject]@{ Name = 'DomainDnsZones'; NamingContext = if ($RootDse.DefaultNamingContext) { "DC=DomainDnsZones,$($RootDse.DefaultNamingContext)" } else { $null } },
        [PSCustomObject]@{ Name = 'ForestDnsZones'; NamingContext = if ($RootDse.RootDomainNamingContext) { "DC=ForestDnsZones,$($RootDse.RootDomainNamingContext)" } else { $null } }
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$definition.NamingContext)) { continue }
        $dnsApplicationPartitions.Add([PSCustomObject][ordered]@{
            Name = $definition.Name
            NamingContext = $definition.NamingContext
            Advertised = $definition.NamingContext -in $advertised
            Status = if ($definition.NamingContext -in $advertised) { 'Advertised' } else { 'NotAdvertisedOnAssessedDc' }
        }) | Out-Null
    }

    $partitionResults = [System.Collections.Generic.List[object]]::new()
    foreach ($namingContext in $advertised) {
        try {
            # A base-scope read proves the advertised partition root is reachable on the assessed DC.
            $entry = Invoke-MtLdapSearch -Connection $Connection -SearchBase $namingContext -Scope Base -Filter '(objectClass=*)' -Attributes @('distinguishedName','objectClass') -PageSize 0 | Select-Object -First 1
            $partitionResults.Add([PSCustomObject][ordered]@{
                NamingContext = $namingContext
                Advertised = $true
                Readable = $null -ne $entry
                Error = if ($null -eq $entry) { 'The LDAP server returned no partition root entry.' } else { $null }
            }) | Out-Null
        }
        catch {
            $partitionResults.Add([PSCustomObject][ordered]@{
                NamingContext = $namingContext
                Advertised = $true
                Readable = $false
                Error = $_.Exception.Message
            }) | Out-Null
        }
    }

    $expectedUnique = [string[]]@($expected | Sort-Object -Unique)
    $missingExpected = [string[]]@($expectedUnique | Where-Object { $_ -notin $advertised })
    return [PSCustomObject][ordered]@{
        AssessedServer = [string]$RootDse.DnsHostName
        AdvertisedNamingContexts = $advertised
        ExpectedCoreNamingContexts = $expectedUnique
        MissingExpectedNamingContexts = $missingExpected
        DnsApplicationPartitions = @($dnsApplicationPartitions)
        AdvertisedDnsApplicationPartitionCount = @($dnsApplicationPartitions | Where-Object Advertised).Count
        UnadvertisedDnsApplicationPartitionCount = @($dnsApplicationPartitions | Where-Object { -not $_.Advertised }).Count
        PartitionResults = @($partitionResults)
        AdvertisedCount = $advertised.Count
        ReadableCount = @($partitionResults | Where-Object Readable).Count
        UnreadableCount = @($partitionResults | Where-Object { -not $_.Readable }).Count
        MissingExpectedCount = $missingExpected.Count
    }
}