<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy enforcing non persistent browser session

 .Description
    Non persistent browser session conditional access policy can be helpful to minimize the risk of data leakage from a unmanaged device.

  Learn more:
  https://aka.ms/CATemplatesBrowserSession

 .Example
  Test-MtCaEnforceNonPersistentBrowserSession

.LINK
    https://maester.dev/docs/commands/Test-MtCaEnforceNonPersistentBrowserSession
#>
function Test-MtCaEnforceNonPersistentBrowserSession {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        # Ignore device filters for compliant devices.
        [switch]$AllDevices
    )

    if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }

        $testDescription = '
Microsoft recommends disabling browser persistence for users accessing the tenant from a unmanaged device.

See [Require reauthentication and disable browser persistence - Microsoft Learn](https://aka.ms/CATemplatesBrowserSession)'
        $testResult = "These conditional access policies enforce the use of a compliant device :`n`n"

        $result = $false
        foreach ($policy in $policies) {
            if (-not $AllDevices.IsPresent) {
                # Check if device filter for compliant or hybrid Azure AD joined devices is present
                if ( $policy.conditions.devices.deviceFilter.mode -eq 'include' -and
                    (
                        (
                            $policy.conditions.devices.deviceFilter.rule -match 'device.trustType -ne \"ServerAD\"' -and
                            $policy.conditions.devices.deviceFilter.rule -match 'device.isCompliant -ne True'
                        ) -or $policy.conditions.devices.deviceFilter.rule -match 'device.isCompliant -ne True'
                    )
                ) {
                    $IsDeviceFilterPresent = $true
                } elseif ( $policy.conditions.devices.deviceFilter.mode -eq 'exclude' -and
                    (
                        (
                            $policy.conditions.devices.deviceFilter.rule -match 'device.trustType -eq \"ServerAD\"' -and
                            $policy.conditions.devices.deviceFilter.rule -match 'device.isCompliant -eq True'
                        ) -or
                        $policy.conditions.devices.deviceFilter.rule -match 'device.isCompliant -eq True'
                    )
                ) {
                    $IsDeviceFilterPresent = $true
                } else {
                    $IsDeviceFilterPresent = $false
                }
            } else {
                Write-Verbose 'All devices are selected'
                # We don't care about device filter if we are checking for all devices
                $IsDeviceFilterPresent = $true
            }

            if ( $policy.sessionControls.persistentBrowser.isEnabled -eq $true -and
                $policy.sessionControls.persistentBrowser.mode -eq 'never' -and
                $IsDeviceFilterPresent -and
                $policy.conditions.users.includeUsers -eq 'All' -and
                $policy.conditions.applications.includeApplications -eq 'All'
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
            $testResult = 'There was no conditional access policy enforcing non persistent browser session for non-corporate devices.'
        }

        Add-MtTestResultDetail -Description $testDescription -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}

