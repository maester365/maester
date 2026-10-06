function Test-MtCheckEidscaAM04 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications is 'all_users'

    .DESCRIPTION
    Object Id or scope of users which will be showing number matching in the Authenticator App.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    .featureSettings.numberMatchingRequiredState.includeTarget.id with Test-MtEidscaAM04
    and passes when it -eq 'all_users'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AM04',
        Title = 'Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications.',
        Severity = 'Medium',
        Category = 'EIDSCA',
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

    $tenantValue = Test-MtEidscaAM04
    return ($tenantValue -eq 'all_users')
}
