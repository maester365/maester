function Test-MtDeviceRegistrationMfaConflict {
    <#
    .Synopsis
    This function checks if MFA during device registration is being enforced in Entra ID settings and in Conditional Access policies.

    .Description
    When MFA is required during device registration in Conditional Access policies, it must be disabled in the Entra ID Device settings.
    When both are enabled, the Conditional Access policy with the "Register or join devices" user action will not work as expected. More information
    can be found at: https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-registration#create-a-conditional-access-policy

    .Example
    Test-MtDeviceRegistrationMfaConflict

    .LINK
    https://maester.dev/docs/commands/Test-MtDeviceRegistrationMfaConflict
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    # Testing connection with graph
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        # Initialize the test result variables
        $testResultMarkdown = ""

        # Get the enabled Conditional Access policies
        $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
        Write-Verbose "Retrieved Conditional Access policies:`n $policies"

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
                Write-Verbose "Found Conditional Access policies that require MFA for device registration: $($deviceRegPolicies.Count)"
                $testResultMarkdown = "Device registration controls are enforced in both Conditional Access and [Entra - Device Settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices). Disable the tenant wide setting and enforce through Conditional Access."
                $return = $false
            } else {
                Write-Verbose "No Conditional Access policies requiring MFA for device registration were found."
                $testResultMarkdown = "Well done. Requiring MFA for device registration is enforced at the tenant level."
                $return = $true
            }
        } else {
            # If MFA is not required for device registration in Entra ID settings
            Write-Verbose "Device registration MFA is not required in Entra ID settings."
            # If MFA is not required for device registration in Entra ID settings, we need to check if there are any policies that require controls on register device
            if ($deviceRegPoliciesCount -gt 0) {
                Write-Verbose "Found Conditional Access policies that require controls on Register or join devices: $($deviceRegPolicies.Count)"
                $testResultMarkdown = "Well done. Requiring controls for device registration is enforced with Conditional Access policies."
                $return = $true
            } else {
                Write-Verbose "No controls were found for registering devices in Conditional Access policies."
                $testResultMarkdown = "No conflicting Conditional Access policy was found, and the tenant-wide MFA requirement for device registration is not enforced. It is recommended to enforce MFA for device registration with Conditional Access."
                $return = $true
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $deviceRegPolicies

    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    }

    return $return
}
