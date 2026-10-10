function Test-MtCheckEidscaAM09 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications is 'enabled'

    .DESCRIPTION
    Determines whether the user's Authenticator app will show them the geographic location of where the authentication request originated from.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    .featureSettings.displayLocationInformationRequiredState.state with Test-MtEidscaAM09
    and passes when it -eq 'enabled'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AM09',
        Title = 'Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications.',
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

    $tenantValue = Test-MtEidscaAM09
    return ($tenantValue -eq 'enabled')
}
