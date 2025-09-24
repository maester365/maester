<#
 .Synopsis
  Checks if the tenant has at least one Conditional Access policy is configured to block access for unknown or unsupported device platforms

 .Description
    Microsoft recommends blocking access for unknown or unsupported device platforms.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-policy-unknown-unsupported-device

 .Example
  Test-MtCaBlockUnknownOrUnsupportedDevicePlatform

.LINK
    https://maester.dev/docs/commands/Test-MtCaBlockUnknownOrUnsupportedDevicePlatform
#>
function Test-MtCaBlockUnknownOrUnsupportedDevicePlatform {
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
Microsoft recommends blocking access for unknown or unsupported device platforms.

See [Block access for unknown or unsupported device platform - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-policy-unknown-unsupported-device)'
        $testResult = "These conditional access policies block access for unknown or unsupported device platforms:`n`n"

        $result = $false
        foreach ($policy in $policies) {
            if ( $policy.grantControls.builtInControls -eq 'block' `
                    -and $policy.conditions.platforms.includePlatforms -eq 'All'
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
            $testResult = 'There was no conditional access policy blocking access for unknown or unsupported device platforms.'
        }
        Add-MtTestResultDetail -Description $testDescription -Result $testResult

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
