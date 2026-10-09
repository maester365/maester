function Test-MtCheckEidscaAT02 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Temporary Access Pass - One-time is 'true'

    .DESCRIPTION
    Determines whether the pass is limited to a one-time use.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
    .isUsableOnce with Test-MtEidscaAT02
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AT02',
        Title = 'Authentication Method - Temporary Access Pass - One-time.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EnabledAuthMethods = (Get-MtAuthenticationMethodPolicyConfig -State Enabled).Id
    if ( $EnabledAuthMethods -notcontains 'TemporaryAccessPass' ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of Temporary Access Pass is not enabled.'
        return $null
    }

    $tenantValue = Test-MtEidscaAT02
    return ($tenantValue -eq 'true')
}
