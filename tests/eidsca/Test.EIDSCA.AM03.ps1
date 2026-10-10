function Test-MtCheckEidscaAM03 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Require number matching for push notifications is 'enabled'

    .DESCRIPTION
    Defines if number matching is required for MFA notifications.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    .featureSettings.numberMatchingRequiredState.state with Test-MtEidscaAM03
    and passes when it -eq 'enabled'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AM03',
        Title = 'Authentication Method - Microsoft Authenticator - Require number matching for push notifications.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
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

    $tenantValue = Test-MtEidscaAM03
    return ($tenantValue -eq 'enabled')
}
