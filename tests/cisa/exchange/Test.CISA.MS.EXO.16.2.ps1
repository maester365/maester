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
        Id = 'CISA.MS.EXO.16.2',
        Title = 'Alerts SHOULD be sent to a monitored address or incorporated into a security information and event management (SIEM) system.',
        Severity = 'Medium',
        Category = 'CISA',
        Tag = ('MS.EXO', 'MS.EXO.16.2'),
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        CompatibleLicense = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not available for API validation.'
    return $null
}
