function Test-MtCheckEidscaAT01 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Temporary Access Pass - State is 'enabled'

    .DESCRIPTION
    Whether the Temporary Access Pass is enabled in the tenant.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
    .state with Test-MtEidscaAT01
    and passes when it -eq 'enabled'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AT01',
        Title = 'Authentication Method - Temporary Access Pass - State.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAT01
    return ($tenantValue -eq 'enabled')
}
