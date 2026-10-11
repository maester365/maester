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
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1621', 'T1078.004'),
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAG02
    return ($tenantValue -eq 'enabled')
}
