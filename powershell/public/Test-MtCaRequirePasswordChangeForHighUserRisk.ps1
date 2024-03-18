<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring password change for high user risk.

 .Description
    Password change for high user risk is a good way to prevent compromised accounts from being used to access your tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-risk-user

 .Example
  Test-MtCaRequirePasswordChangeForHighUserRisk
#>

Function Test-MtCaRequirePasswordChangeForHighUserRisk {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Set-StrictMode -Off
    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }
    # Only check policies that have password change as a grant control
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -contains 'passwordChange' }

    $result = $false
    foreach ($policy in $policies) {
        if ( $policy.grantcontrols.builtincontrols -contains 'passwordChange' `
                -and $policy.conditions.users.includeUsers -eq "All" `
                -and $policy.conditions.applications.includeApplications -eq "All" `
                -and "high" -in $policy.conditions.userRiskLevels `
        ) {
            $result = $true
            $currentresult = $true
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }
    Set-StrictMode -Version Latest

    return $result
}