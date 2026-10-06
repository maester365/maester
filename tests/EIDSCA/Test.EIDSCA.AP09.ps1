function Test-MtCheckEidscaAP09 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Allow user consent on risk-based apps is 'false'

    .DESCRIPTION
    Indicates whether user consent for risky apps is allowed. For example, consent requests for newly registered multi-tenant apps that are not publisher verified and require non-basic permissions are considered risky.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .allowUserConsentForRiskyApps with Test-MtEidscaAP09
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP09',
        Title = 'Default Authorization Settings - Allow user consent on risk-based apps.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAP09
    return ($tenantValue -eq 'false')
}
