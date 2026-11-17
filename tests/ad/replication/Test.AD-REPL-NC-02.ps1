function Test-MtAdReplicationCoreNamingContextsPresent {
    <#
    .SYNOPSIS
        Checks that expected core naming contexts are advertised by the assessed DC.
    #>
    [MaesterTest(
        Id = 'AD-REPL-NC-02',
        Title = 'Expected core naming contexts should be present',
        Product = 'ad',
        Feature = 'replication',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:domainDNS:ReadProperty',
        Author = 'rolling-code'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState -Categories ReplicationPartitions
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    if ($null -eq $adState['ReplicationPartitionState']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Replication partition evidence is unavailable.'
        return $null
    }
    $state = $adState['ReplicationPartitionState']
    if (-not $state.CoreNamingContextAssessmentAvailable) {
        $missingAttributes = @($state.MissingCoreRootDseAttributes) -join ', '
        Add-MtTestResultDetail -Result "Mandatory RootDSE naming-context evidence was not returned. Core naming-context coverage is unavailable. Missing attributes: $missingAttributes"
        return $null
    }
    $result = "| Assessed DC | Expected core | Missing |`n| --- | ---: | ---: |`n"
    $result += "| $($state.AssessedServer) | $(@($state.ExpectedCoreNamingContexts).Count) | $($state.MissingExpectedCount) |"
    if ($state.MissingExpectedCount -gt 0) {
        $result += "`n`nMissing expected naming contexts:`n"
        foreach ($namingContext in @($state.MissingExpectedNamingContexts)) { $result += "`n- $namingContext" }
    }
    Add-MtTestResultDetail -Result $result
    return ($state.MissingExpectedCount -eq 0)
}
