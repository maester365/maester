function Test-MtCheckEidscaAG02 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - General Settings - Report suspicious activity - State is 'enabled'

    .DESCRIPTION
    Allows users to report suspicious activities if they receive an authentication request that they did not initiate. This control is available when using the Microsoft Authenticator app and voice calls. Reporting suspicious activity will set the user's risk to high. If the user is subject to risk-based Conditional Access policies, they may be blocked.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy
    .reportSuspiciousActivitySettings.state with Test-MtEidscaAG02
    and passes when it -eq 'enabled'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AG02',
        Title = 'Authentication Method - General Settings - Report suspicious activity - State.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAG02
    return ($tenantValue -eq 'enabled')
}
