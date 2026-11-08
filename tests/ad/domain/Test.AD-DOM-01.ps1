function Test-MtAdDomainFunctionalLevel {
    <#
    .SYNOPSIS
    Assesses the connected domain functional level against its scoped DC support.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-DOM-01',
        Title = 'Domain functional level meets the highest supported common level',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'High',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Domain', 'DomainControllers')
    if (-not $state) { throw 'Domain snapshot unavailable.' }
    $scope = [pscustomobject]@{ Domain = $state.Domain; DomainControllers = @(Get-MtAdDomainControllersInScope -State $state) }
    $assessment = Get-MtAdFunctionalLevelAssessment -State $scope -Scope Domain
    $ok = $assessment.Current -eq $assessment.Target
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done.' } elseif ($assessment.Current -gt $assessment.Target) { 'Configured level exceeds collected DC support; verify incompatible or stale DC inventory before taking action.' } else { 'Raise the domain functional level after planning DC upgrades.' }) Current raw level: $($assessment.Current); highest common supported level: $($assessment.Target). Level 7 supports 2016/2019/2022 DCs; level 10 requires all 2025 DCs."
    return $ok
}
