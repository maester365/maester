<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy enforcing sign-in frequency for non-corporate devices

 .Description
    Sign-in frequency conditional access policy can be helpful to minimize the risk of data leakage from a shared device.

  Learn more:
  https://aka.ms/CATemplatesBrowserSession

 .Example
  Test-MtCaEnforceSignInFrequency
#>

Function Test-MtCaEnforceSignInFrequency {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        [switch]$AllDevices
    )

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $result = $false
    foreach ($policy in $policies) {
        # Check if device filter for compliant or hybrid Azure AD joined devices is present
        if (-not $AllDevices.IsPresent) {
            if ( $policy.conditions.devices.deviceFilter.mode -eq "include" `
                    -and $policy.conditions.devices.deviceFilter.rule -match 'device.trustType -ne \"ServerAD\"' `
                    -and $policy.conditions.devices.deviceFilter.rule -match 'device.isCompliant -ne True' `
            ) {
                $IsDeviceFilterPresent = $true
            } elseif ( $policy.conditions.devices.deviceFilter.mode -eq "exclude" `
                    -and $policy.conditions.devices.deviceFilter.rule -match 'device.trustType -eq \"ServerAD\"' `
                    -and $policy.conditions.devices.deviceFilter.rule -match 'device.isCompliant -eq True' `
            ) {
                $IsDeviceFilterPresent = $true
            } else {
                $IsDeviceFilterPresent = $false
            }
        } else {
            # We don't care about device filter if we are checking for all devices
            $IsDeviceFilterPresent = $true
        }
        if ( $policy.sessionControls.signInFrequency.isEnabled -eq $true `
                -and $policy.sessionControls.signInFrequency.frequencyInterval -eq "timeBased" `
                -and $IsDeviceFilterPresent `
                -and $policy.conditions.users.includeUsers -eq "All" `
                -and $policy.conditions.applications.includeApplications -eq "All" `
        ) {
            $result = $true
            $currentresult = $true
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    return $result
}