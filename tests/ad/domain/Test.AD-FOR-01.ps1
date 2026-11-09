function Test-MtAdForestFunctionalLevel {
    <#
    .SYNOPSIS
    Assesses the forest functional level against connected-domain DC support.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-FOR-01',
        Title = 'Forest functional level meets connected-domain DC support',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'High',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty', 'ActiveDirectory:Ldap:crossRef:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Domain', 'Forest', 'DomainControllers')
    $controllers = @(Get-MtAdDomainControllersInScope -State $state)
    $scopedState = [pscustomobject]@{ Forest = $state.Forest; DomainControllers = $controllers }
    $assessment = Get-MtAdFunctionalLevelAssessment -State $scopedState -Scope Forest
    $excludedCount = @($state.DomainControllers).Count - $controllers.Count
    $ok = $assessment.Current -eq $assessment.Target
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done. The forest level matches connected-domain DC support.' } elseif ($assessment.Current -gt $assessment.Target) { 'Configured level exceeds connected-domain DC support; verify incompatible or stale DC inventory before taking action.' } else { 'The forest level is below connected-domain DC capability. Assess every other domain before planning any forest-level change.' }) Domain assessed: $($state.Domain.DnsRoot); current raw forest level: $($assessment.Current); common supported level for assessed DCs: $($assessment.Target); assessed DCs: $($controllers.Count); other-domain DCs excluded: $excludedCount. This scoped result does not establish forest-wide upgrade eligibility. Level 10 requires every forest DC on Server 2025 and compatible domain functional levels."
    return $ok
}
