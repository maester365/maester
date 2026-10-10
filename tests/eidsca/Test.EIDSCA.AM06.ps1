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

    $tenantValue = Test-MtEidscaAM06
    return ($tenantValue -eq 'enabled')
}
