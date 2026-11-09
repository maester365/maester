function Test-MtCisaMailboxIntelligence {
    <#
    .SYNOPSIS
    This retired CISA requirement is no longer assessed.

    .DESCRIPTION
    CISA removed this requirement from the SCuBA baseline in April 2026.

    .EXAMPLE
    Test-MtCisaMailboxIntelligence

    Returns $null because this deprecated check is skipped; CISA removed the requirement from SCuBA.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaMailboxIntelligence
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.11.3',
        Title = 'The phishing protection solution SHOULD include an AI-based phishing detection tool comparable to EOP Mailbox Intelligence.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-phishing',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = 'cisa-scuba:MS.EXO.11.3',
        Service = 'None',
        Lifecycle = 'Deprecated',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "CISA removed MS.EXO.11.3 from the SCuBA baseline in April 2026. This legacy check is no longer assessed."
    return $null
}
