function Test-MtAdReplicationNamingContextsReadable {
    <#
    .SYNOPSIS
        Checks that every naming context advertised by the assessed DC is readable.
    #>
    [MaesterTest(
        Id = 'AD-REPL-NC-01',
        Title = 'Advertised naming contexts should be readable',
        Product = 'ad',
        Feature = 'replication',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty','ActiveDirectory:Ldap:Configuration/*:ReadProperty','ActiveDirectory:Ldap:Schema/*:ReadProperty'),
        Author = 'rolling-code'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState -Categories ReplicationPartitions
    if ($null -eq $adState -or $null -eq $adState['ReplicationPartitionState']) { return $null }
    $state = $adState['ReplicationPartitionState']
    $result = "| Assessed DC | Advertised | Readable | Unreadable |`n| --- | ---: | ---: | ---: |`n"
    $result += "| $($state.AssessedServer) | $($state.AdvertisedCount) | $($state.ReadableCount) | $($state.UnreadableCount) |"
    if ($state.UnreadableCount -gt 0) {
        $result += "`n`n| Unreadable naming context | Error |`n| --- | --- |"
        foreach ($partition in @($state.PartitionResults | Where-Object { -not $_.Readable })) {
            $result += "`n| $($partition.NamingContext) | $($partition.Error -replace '\|','\\|') |"
        }
    }
    Add-MtTestResultDetail -Result $result
    return ($state.AdvertisedCount -gt 0 -and $state.UnreadableCount -eq 0)
}