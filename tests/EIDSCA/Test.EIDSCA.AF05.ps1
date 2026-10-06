function Test-MtCheckEidscaAF05 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restricted is 'true'

    .DESCRIPTION
    You can work with your Security key provider to determine the AAGuids of their devices for allowing or blocking usage.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    .keyRestrictions.aaGuids -notcontains $null with Test-MtEidscaAF05
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AF05',
        Title = 'Authentication Method - FIDO2 security key - Restricted.',
        Severity = 'High',
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

    $tenantValue = Test-MtEidscaAF05
    return ($tenantValue -eq 'true')
}
