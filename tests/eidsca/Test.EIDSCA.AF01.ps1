function Test-MtCheckEidscaAF01 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - State is 'enabled'

    .DESCRIPTION
    Whether the FIDO2 security keys is enabled in the tenant.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    .state with Test-MtEidscaAF01
    and passes when it -eq 'enabled'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AF01',
        Title = 'Authentication Method - FIDO2 security key - State.',
        Severity = 'High',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAF01
    return ($tenantValue -eq 'enabled')
}
