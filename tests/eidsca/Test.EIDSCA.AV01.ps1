function Test-MtCheckEidscaAV01 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Voice call - State is 'disabled'

    .DESCRIPTION
    Whether the Voice call is enabled in the tenant.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')
    .state with Test-MtEidscaAV01
    and passes when it -eq 'disabled'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AV01',
        Title = 'Authentication Method - Voice call - State.',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1621',
        Control = ('nist-800-53-r5:CM-7', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAV01
    return ($tenantValue -eq 'disabled')
}
