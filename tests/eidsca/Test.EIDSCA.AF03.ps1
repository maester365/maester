function Test-MtCheckEidscaAF03 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Enforce attestation is 'true'

    .DESCRIPTION
    Requires the FIDO security key metadata to be published and verified with the FIDO Alliance Metadata Service, and also pass Microsoft's additional set of validation testing.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    .isAttestationEnforced with Test-MtEidscaAF03
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AF03',
        Title = 'Authentication Method - FIDO2 security key - Enforce attestation.',
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

    $tenantValue = Test-MtEidscaAF03
    return ($tenantValue -eq 'true')
}
