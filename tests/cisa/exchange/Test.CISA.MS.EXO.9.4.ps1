function Test-MtCisaEmailFilterAlternative {
    <#
    .SYNOPSIS
    This retired CISA requirement is no longer assessed.

    .DESCRIPTION
    CISA removed this requirement from the SCuBA baseline in April 2026.

    .EXAMPLE
    Test-MtCisaEmailFilterAlternative

    Always returns null

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaEmailFilterAlternative
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.9.4',
        Title = 'Alternatively chosen filtering solutions SHOULD offer services comparable to Microsoft Defender''s Common Attachment Filter.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-malware',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1204.002', 'T1566.001'),
        Control = 'cisa-scuba:MS.EXO.9.4',
        Service = 'None',
        Lifecycle = 'Deprecated',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'SamErde')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "CISA removed MS.EXO.9.4 from the SCuBA baseline in April 2026. This legacy check is no longer assessed."
    return $null
}
