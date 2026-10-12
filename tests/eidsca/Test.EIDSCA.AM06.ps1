function Test-MtCheckEidscaAM06 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications is 'enabled'

    .DESCRIPTION
    Determines whether the user's Authenticator app will show them the client app they are signing into.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    .featureSettings.displayAppInformationRequiredState.state with Test-MtEidscaAM06
    and passes when it -eq 'enabled'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AM06',
        Title = 'Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications.',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1621',
        Control = ('nist-800-53-r5:IA-2(13)', 'nist-800-53-r5:IA-2(1)'),
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EnabledAuthMethods = (Get-MtAuthenticationMethodPolicyConfig -State Enabled).Id
    if ( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of Microsoft Authenticator is not enabled.'
        return $null
    }

    $tenantValue = Test-MtEidscaAM06
    return ($tenantValue -eq 'enabled')
}
