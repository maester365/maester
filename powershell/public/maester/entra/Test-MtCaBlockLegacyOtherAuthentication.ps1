<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy that blocks legacy authentication.

 .Description
    Legacy authentication is an unsecure method to authenticate. This function checks if the tenant has at least one
    conditional access policy that blocks legacy authentication.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy

 .Example
  Test-MtCaBlockLegacyOtherAuthentication

.LINK
    https://maester.dev/docs/commands/Test-MtCaBlockLegacyOtherAuthentication
#>
function Test-MtCaBlockLegacyOtherAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -eq "Free" ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
        # Remove policies that require password change, as they are related to user risk and not MFA on signin
        $policies = $policies | Where-Object { $_.grantControls.builtInControls -notcontains 'passwordChange' }

        $testDescription = "
Legacy authentication is an unsecure method to authenticate. This function checks if the tenant has at least one
conditional access policy that blocks legacy authentication.

See [Block legacy authentication - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy)"
        $testResult = "These conditional access policies block legacy authentication for other clients :`n`n"

        $result = $false
        foreach ($policy in $policies) {
            if ( $policy.grantControls.builtInControls -contains 'block' `
                    -and "other" -in $policy.conditions.clientAppTypes `
                    -and $policy.conditions.applications.includeApplications -eq "All" `
                    -and $policy.conditions.users.includeUsers -eq "All" `
            ) {
                $result = $true
                $CurrentResult = $true
                $testResult += "  - [$($policy.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ($result -eq $false) {
            $testResult = "There was no conditional access policy blocking legacy authentication for other clients."
        }
        Add-MtTestResultDetail -Description $testDescription -Result $testResult

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
