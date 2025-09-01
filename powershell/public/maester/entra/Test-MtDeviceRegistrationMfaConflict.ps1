<#
.Synopsis
    This function checks if MFA during device registration is being enforced in Entra ID settings and in conditional access policies.

.Description
    When MFA is required during device registration in Conditional Access policies, it must be disabled in the Entra ID Device settings.
    When both are enabled, the conditional access policy with the "Register device" user action will not work as expected. More information
    can be found at: https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-all-users-device-registration#create-a-conditional-access-policy

.Example
    Test-MtDeviceRegistrationMfaConflict

.LINK
    https://maester.dev/docs/commands/Test-MtDeviceRegistrationMfaConflict
#>

function Test-MtDeviceRegistrationMfaConflict {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    # Testing conneciton with graph
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        # Initialize the test result variables
        $testResultMarkdown = ""

        # Get the enabled conditional access policies
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
        Write-Verbose "Retrieved conditional access policies:`n $policies"

        # Get device registration settings in Entra ID
        $deviceRegSettings = Invoke-MtGraphRequest -RelativeUri "policies/deviceRegistrationPolicy" -apiVersion "beta"
        Write-Verbose "Retrieved device registration settings:`n $deviceRegSettings"

        # Get all the CA policies that require MFA for device registration
        $deviceRegPolicies = $policies | Where-Object { $_.conditions.applications.includeUserActions -contains "urn:user:registerdevice" }
        $deviceRegPoliciesCount = ($deviceRegPolicies | Measure-Object).Count

        # Check if MFA with Device Registration is required in Entra settings
        $deviceRegMfaRequired = $deviceRegSettings.multiFactorAuthConfiguration -eq "required"

        Write-Verbose "Device registration MFA required in Entra ID settings: $deviceRegMfaRequired"

        if ($deviceRegMfaRequired) {
            Write-Verbose "Device registration MFA is required in Entra ID settings."
            # If MFA is required for device registration in Entra ID settings, we need to check if there are any policies that conflict with this
            if ($deviceRegPoliciesCount -gt 0) {
                Write-Verbose "Found conditional access policies that require MFA for device registration: $($deviceRegPolicies.Count)"
                $testResultMarkdown = "Device registration controls are enforced in both conditional access and [Entra - Device Settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices). Disable the tenant wide setting and enforce through conditional access."
                $return = $false
            } else {
                Write-Verbose "No conditional access policies requiring MFA for device registration were found."
                $testResultMarkdown = "Well done. Requiring MFA for device registration is enforced at the tenant level."
                $return = $true
            }
        } else {
            # If MFA is not required for device registration in Entra ID settings
            Write-Verbose "Device registration MFA is not required in Entra ID settings."
            # If MFA is not required for device registration in Entra ID settings, we need to check if there are any policies that require controls on register device
            if ($deviceRegPoliciesCount -gt 0) {
                Write-Verbose "Found conditional access policies that require controls on register device: $($deviceRegPolicies.Count)"
                $testResultMarkdown = "Well done. Requiring controls for device registration is enforced with conditional access policies."
                $return = $true
            } else {
                Write-Verbose "No controls were found for registering devices in conditional access policies."
                $testResultMarkdown = "No conditional access policies nor device registration settings were found that conflict with each other. However it is recommended to enforce MFA for device registration."
                $return = $true
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $deviceRegPolicies

    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    }

    return $return
}