function Test-MtCheckEidscaAF02 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Allow self-service set up is 'true'

    .DESCRIPTION
    Allows users to register a FIDO key through the MySecurityInfo portal, even if enabled by Authentication Methods policy.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    .isSelfServiceRegistrationAllowed with Test-MtEidscaAF02
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AF02',
        Title = 'Authentication Method - FIDO2 security key - Allow self-service set up.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EnabledAuthMethods = (Get-MtAuthenticationMethodPolicyConfig -State Enabled).Id
    if ( $EnabledAuthMethods -notcontains 'Fido2' ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of FIDO2 security keys is not enabled.'
        return $null
    }

    $tenantValue = Test-MtEidscaAF02
    return ($tenantValue -eq 'true')
}
