function Test-MtCheckEidscaAF06 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restrict specific keys is 'true'

    .DESCRIPTION
    Defines if list of AADGUID will be used to allow or block registration.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    .keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block') with Test-MtEidscaAF06
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AF06',
        Title = 'Authentication Method - FIDO2 security key - Restrict specific keys.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EnabledAuthMethods = (Get-MtAuthenticationMethodPolicyConfig -State Enabled).Id
    # Tenant value of EIDSCA.AF04, read directly so that this test does not call another test.
    $eidscaAF04Result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
    [string]$eidscaAF04Value = $eidscaAF04Result.keyRestrictions.isEnforced
    if ( $EnabledAuthMethods -notcontains 'Fido2' -or $eidscaAF04Value -eq $false ) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of FIDO2 security keys is not enabled and key restriction not enforced.'
        return $null
    }

    $tenantValue = Test-MtEidscaAF06
    return ($tenantValue -eq 'true')
}
