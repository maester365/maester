function Test-MtCheckEidscaAS04 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - SMS - Use for sign-in is 'false'

    .DESCRIPTION
    Determines if users can use this authentication method to sign in to Microsoft Entra ID. true if users can use this method for primary authentication, otherwise false.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')
    .includeTargets.isUsableForSignIn with Test-MtEidscaAS04
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AS04',
        Title = 'Authentication Method - SMS - Use for sign-in.',
        Severity = 'High',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EnabledAuthMethods = (Get-MtAuthenticationMethodPolicyConfig -State Enabled).Id
    if ( $EnabledAuthMethods -notcontains 'Sms' ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of Sms is not enabled.'
        return $null
    }

    $tenantValue = Test-MtEidscaAS04
    return ($tenantValue -eq 'false')
}
