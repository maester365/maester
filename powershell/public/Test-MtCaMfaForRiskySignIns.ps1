<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring multifactor authentication for risky sign-ins.

 .Description
    MFA for risky sign-ins conditional access policy can be used to require MFA for all users in the tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk

 .Example
  Test-MtCaMfaForRiskySignIns
#>

Function Test-MtCaMfaForRiskySignIns {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }
    # Remove policies that require password change, as they are related to user risk and not MFA on signin
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -notcontains 'passwordChange' }

    $result = $false
    foreach ($policy in $policies) {
        if ( ( $policy.grantcontrols.builtincontrols -contains 'mfa' `
                    -or $policy.grantcontrols.authenticationStrength.requirementsSatisfied -contains 'mfa' ) `
                -and $policy.conditions.users.includeUsers -eq "All" `
                -and $policy.conditions.applications.includeApplications -eq "All" `
                -and "high" -in $policy.conditions.signInRiskLevels `
                -and "medium" -in $policy.conditions.signInRiskLevels ) {
            $result = $true
            $currentresult = $true
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    return $result
}