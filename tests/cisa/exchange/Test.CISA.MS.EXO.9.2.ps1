function Test-MtCheckCISAMSEXO92 {
    <#
    .SYNOPSIS
    This retired CISA requirement is no longer assessed.

    .DESCRIPTION
    CISA removed this requirement from the SCuBA baseline in April 2026.
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.9.2',
        Title = 'The attachment filter SHOULD attempt to determine the true file type and assess the file extension.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-malware',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1036.008', 'T1204.002', 'T1566.001'),
        Control = 'cisa-scuba:MS.EXO.9.2',
        Service = 'None',
        Lifecycle = 'Deprecated',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "CISA removed MS.EXO.9.2 from the SCuBA baseline in April 2026 because it could not be configured through Defender and assessed by ScubaGear. This legacy check is no longer assessed."
    return $null
}
