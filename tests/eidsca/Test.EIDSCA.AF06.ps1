function Test-MtCheckEidscaAF06 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restrict specific keys is 'true'

    .DESCRIPTION
    Defines whether the configured AAGUID list is used to allow or block registration.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    .keyRestrictions.aaGuids.Count -gt 0 -and $result.keyRestrictions.aaGuids -notcontains $null -and $result.keyRestrictions.aaGuids -notcontains '' -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block') with Test-MtEidscaAF06
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AF06',
        Title = 'Authentication Method - FIDO2 security key - Restrict specific keys.',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1098.005',
        Control = 'nist-800-53-r5:IA-5',
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
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of FIDO2 security keys is not enabled or key restrictions are not enforced.'
        return $null
    }

    $tenantValue = Test-MtEidscaAF06
    return ($tenantValue -eq 'true')
}
