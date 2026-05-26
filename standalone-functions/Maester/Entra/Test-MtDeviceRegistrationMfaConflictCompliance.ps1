function Test-MtDeviceRegistrationMfaConflictCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtDeviceRegistrationMfaConflictCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    # Testing conneciton with graph

    try {
        # Initialize the test result variables

        # Get the enabled conditional access policies
        $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq "enabled" }
        Write-Verbose "Retrieved conditional access policies:`n $policies"

        # Get device registration settings in Entra ID
        $deviceRegSettings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/deviceRegistrationPolicy' -apiVersion "beta"
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
                $return = $false
            } else {
                Write-Verbose "No conditional access policies requiring MFA for device registration were found."
                $return = $true
            }
        } else {
            # If MFA is not required for device registration in Entra ID settings
            Write-Verbose "Device registration MFA is not required in Entra ID settings."
            # If MFA is not required for device registration in Entra ID settings, we need to check if there are any policies that require controls on register device
            if ($deviceRegPoliciesCount -gt 0) {
                Write-Verbose "Found conditional access policies that require controls on register device: $($deviceRegPolicies.Count)"
                $return = $true
            } else {
                Write-Verbose "No controls were found for registering devices in conditional access policies."
                $return = $true
            }
        }


    } catch {
    }

    return $return

}
