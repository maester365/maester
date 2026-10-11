function Test-MtCisaAppGroupOwnerConsent {
    <#
    .SYNOPSIS
    Checks if group owners can consent to apps

    .DESCRIPTION
    Group owners SHALL NOT be allowed to consent to applications.

    .EXAMPLE
    Test-MtCisaAppGroupOwnerConsent

    Returns true if disabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAppGroupOwnerConsent
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.5.4',
        Title = 'Group owners SHALL NOT be allowed to consent to applications.',
        Product = 'entra',
        Feature = 'app-consent',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1528', 'T1566.002'),
        Service = 'Graph',
        Lifecycle = 'Deprecated',
        Author = 'soulemike',
        Contributor = ('michaelmsonne', 'weyCC81', 'SamErde')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This test has been deprecated by CISA as of March 2025 (MS.AAD.5.4v1)."
    return $null
}
