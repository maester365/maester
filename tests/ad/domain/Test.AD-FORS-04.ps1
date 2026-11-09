function Test-MtAdCrossForestReferencesCount {
    <#
    .SYNOPSIS
    Assesses the cached Active Directory snapshot without inferring missing data.
    .DESCRIPTION
    Uses directory metadata; incomplete or unavailable required inventory raises an error.
    .EXAMPLE
    Invoke-MtTest -Id AD-FORS-04
    Review the forest cross-reference inventory manually.
    .LINK
    https://maester.dev/docs/tests/AD-FORS-04
    #>
    [MaesterTest(
        Id = 'AD-FORS-04',
        Title = 'Forest cross-reference inventory for review',
        Product = 'ad',
        Feature = 'domain-and-forest',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:crossRef:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Forest')
    if (-not $state.Forest -or $null -eq $state.Forest.CrossForestReferences) { throw 'Forest cross-reference inventory not collected.' }
    $refs = @($state.Forest.CrossForestReferences)
    Add-MtTestResultDetail -Result "Cross-reference metadata entries: $($refs.Count). CrossRefs describe naming contexts; they do not establish trust, principal access or cross-forest authentication. Review trust objects separately." -Investigate
}
