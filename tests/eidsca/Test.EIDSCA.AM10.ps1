function Test-MtCheckEidscaAM10 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications is 'all_users'

    .DESCRIPTION
    Object Id or scope of users which will be showing geographic location in the Authenticator App.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    .featureSettings.displayLocationInformationRequiredState.includeTarget.id with Test-MtEidscaAM10
    and passes when it -eq 'all_users'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AM10',
        Title = 'Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications.',
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

    $tenantValue = Test-MtEidscaAM10
    return ($tenantValue -eq 'all_users')
}
