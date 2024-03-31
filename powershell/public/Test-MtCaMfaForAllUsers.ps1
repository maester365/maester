<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring multifactor authentication for all users

 .Description
    MFA for all users conditional access policy can be used to require MFA for all users in the tenant.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa

 .Example
  Test-MtCaMfaForAllUsers
#>

Function Test-MtCaMfaForAllUsers {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification='AllUsers is a well known term for conditional access policies.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
    # Remove policies that require password change, as they are related to user risk and not MFA on signin
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -notcontains 'passwordChange' }

    $testDescription = "
This test checks if the tenant has at least one conditional access policy requiring MFA for all users.

See [Require MFA for all users - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa)"
    $testResult = "The following conditional access policies require multi-factor authentication for all users:`n`n"

    $result = $false
    foreach ($policy in $policies) {
        if ( ( $policy.grantcontrols.builtincontrols -contains 'mfa' `
                    -or $policy.grantcontrols.authenticationStrength.requirementsSatisfied -contains 'mfa' ) `
                -and $policy.conditions.users.includeUsers -eq "All" `
                -and $policy.conditions.applications.includeApplications -eq "All" `
        ) {
            $result = $true
            $currentresult = $true
            $testResult += "  - [$($policy.displayname)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    if ( $result -eq $false ) {
        $testResult = "No conditional access policy requires multi-factor authentication for all users"
    }
    Add-MtTestResultDetail -Description $testDescription -Result $testResult

    return $result
}