function Test-MtCheckEidscaAM07 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications is 'all_users'

    .DESCRIPTION
    Object Id or scope of users which will be showing app information in the Authenticator App.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    .featureSettings.displayAppInformationRequiredState.includeTarget.id with Test-MtEidscaAM07
    and passes when it -eq 'all_users'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AM07',
        Title = 'Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications.',
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

    $tenantValue = Test-MtEidscaAM07
    return ($tenantValue -eq 'all_users')
}
