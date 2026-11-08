function Test-MtAdForestFunctionalLevel {
    <#
    .SYNOPSIS
    Assesses the forest functional level against supported levels of all forest DCs.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    #>
    [MaesterTest(
        Id = 'AD-FOR-01',
        Title = 'Forest functional level meets the highest supported common level',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'High',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:crossRef:ReadProperty', 'ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Forest', 'DomainControllers')
    $assessment = Get-MtAdFunctionalLevelAssessment -State $state -Scope Forest
    $ok = $assessment.Current -eq $assessment.Target
    Add-MtTestResultDetail -Result "$(if ($ok) { 'Well done.' } elseif ($assessment.Current -gt $assessment.Target) { 'Configured level exceeds collected DC support; verify incompatible or stale DC inventory before taking action.' } else { 'Plan forest functional level elevation after all DCs and domain functional levels support the target.' }) Current raw forest level: $($assessment.Current); highest common supported level: $($assessment.Target). Level 10 requires every forest DC on Server 2025."
    return $ok
}
