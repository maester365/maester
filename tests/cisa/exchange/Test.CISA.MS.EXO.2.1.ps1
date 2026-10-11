function Test-MtCisaSpfRestriction {
    <#
    .SYNOPSIS
    Checks state of SPF records for all exo domains

    .DESCRIPTION
    A list of approved IP addresses for sending mail SHALL be maintained.

    .EXAMPLE
    Test-MtCisaSpfRestriction

    Returns true if SPF record exists and has a fail all modifier for all exo domains

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpfRestriction
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.2.1',
        Title = 'A list of approved IP addresses for sending mail SHALL be maintained.',
        Product = 'exchange',
        Feature = 'email-authentication',
        Area = 'email-protection',
        ResourceType = 'Domain',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1684.002',
        Service = 'Graph',
        Lifecycle = 'Deprecated',
        Author = 'soulemike',
        Contributor = ('weyCC81', 'SamErde')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This test has been deprecated by CISA as of May 2024 (MS.EXO.2.1v1)."
    return $null
}
