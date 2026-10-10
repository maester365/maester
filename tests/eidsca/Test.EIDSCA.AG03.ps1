function Test-MtCheckEidscaAG03 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - General Settings - Report suspicious activity - Included users/groups is 'all_users'

    .DESCRIPTION
    Object Id or scope of users which will be included to report suspicious activities if they receive an authentication request that they did not initiate.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy
    .reportSuspiciousActivitySettings.includeTarget.id with Test-MtEidscaAG03
    and passes when it -eq 'all_users'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AG03',
        Title = 'Authentication Method - General Settings - Report suspicious activity - Included users/groups.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAG03
    return ($tenantValue -eq 'all_users')
}
