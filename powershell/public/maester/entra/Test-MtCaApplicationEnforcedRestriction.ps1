<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy is configured to enable application enforced restrictions

 .Description
    Application enforced restrictions conditional access policy can be helpful to minimize the risk of data leakage from a shared device.

  Learn more:
  https://aka.ms/CATemplatesAppRestrictions

 .Example
  Test-MtCaApplicationEnforcedRestriction

.LINK
    https://maester.dev/docs/commands/Test-MtCaApplicationEnforcedRestriction
#>
function Test-MtCaApplicationEnforcedRestriction {
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
Microsoft recommends blocking or limiting access to SharePoint, OneDrive, and Exchange content from unmanaged devices.

See [Use application enforced restrictions for unmanaged devices - Microsoft Learn](https://aka.ms/CATemplatesAppRestrictions)'
        $testResult = "These conditional access policies enforce restrictions for unmanaged devices:`n`n"

        $result = $false
        foreach ($policy in $policies) {
            if ( $policy.conditions.users.includeUsers -eq 'All' `
                    -and $policy.conditions.clientAppTypes -eq 'All' `
                    -and $policy.sessionControls.applicationEnforcedRestrictions.isEnabled -eq $true `
                    -and 'Office365' -in $policy.conditions.applications.includeApplications `
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
            $testResult = 'There was no conditional access policy enforcing restrictions for unmanaged devices.'
        }

        Add-MtTestResultDetail -Description $testDescription -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
