function Test-MtCisaExoAlertSiem {
    <#
    .SYNOPSIS
    Checks state of alerts

    .DESCRIPTION
    Alerts SHOULD be sent to a monitored address or incorporated into a security information and event management (SIEM) system.

    .EXAMPLE
    Test-MtCisaExoAlertSiem

    Returns null

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaExoAlertSiem
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.4.2',
        Title = 'The alerts SHOULD be sent to a monitored address or incorporated into a Security Information and Event Management (SIEM).',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'alerts',
        Area = 'logging-and-detection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Control = 'cisa-scuba:MS.SECURITYSUITE.4.2',
        Service = 'None',
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not available for API validation.'
    return $null
}
