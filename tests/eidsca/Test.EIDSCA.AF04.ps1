function Test-MtCheckEidscaAF04 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Enforce key restrictions is 'true'

    .DESCRIPTION
    Manages if registration of FIDO2 keys should be restricted.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    .keyRestrictions.isEnforced with Test-MtEidscaAF04
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AF04',
        Title = 'Authentication Method - FIDO2 security key - Enforce key restrictions.',
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
    if ( $EnabledAuthMethods -notcontains 'Fido2' ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of FIDO2 security keys is not enabled.'
        return $null
    }

    $tenantValue = Test-MtEidscaAF04
    return ($tenantValue -eq 'true')
}
