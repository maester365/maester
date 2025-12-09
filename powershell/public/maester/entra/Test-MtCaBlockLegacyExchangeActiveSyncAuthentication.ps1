<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy that blocks legacy authentication for Exchange Active Sync authentication.

 .Description
    Legacy authentication is an unsecure method to authenticate. This function checks if the tenant has at least one
    conditional access policy that blocks legacy authentication.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy

 .Example
  Test-MtCaBlockLegacyExchangeActiveSyncAuthentication

.LINK
    https://maester.dev/docs/commands/Test-MtCaBlockLegacyExchangeActiveSyncAuthentication
#>
function Test-MtCaBlockLegacyExchangeActiveSyncAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }

        $testDescription = '
Legacy authentication is an unsecure method to authenticate. This function checks if the tenant has at least one
conditional access policy that blocks legacy authentication.

See [Block legacy authentication - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy)'
        $testResult = "These conditional access policies block legacy authentication for Exchange Active Sync:`n`n"


        $result = $false
        foreach ($policy in $policies) {
            if ( $policy.grantControls.builtInControls -contains 'block' -and
                'exchangeActiveSync' -in $policy.conditions.clientAppTypes -and (
                    $policy.conditions.applications.includeApplications -eq '00000002-0000-0ff1-ce00-000000000000' -or
                    $policy.conditions.applications.includeApplications -eq 'All'
                ) -and $policy.conditions.users.includeUsers -eq 'All'
            ) {
                $result = $true
                $currentResult = $true
                $testResult += "  - [$($policy.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
            } else {
                $currentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $currentResult"
        }

        if ($result -eq $false) {
            $testResult = 'There was no conditional access policy blocking legacy authentication for Exchange Active Sync.'
        }

        Add-MtTestResultDetail -Description $testDescription -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
