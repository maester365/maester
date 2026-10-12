function Test-MtCheckEidscaAM01 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - State is 'enabled'

    .DESCRIPTION
    Whether the Authenticator App is enabled in the tenant.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    .state with Test-MtEidscaAM01
    and passes when it -eq 'enabled'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AM01',
        Title = 'Authentication Method - Microsoft Authenticator - State.',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1110',
        Control = ('nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-2(2)'),
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAM01
    return ($tenantValue -eq 'enabled')
}
