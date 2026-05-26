function Test-MtCaMfaForGuestCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaMfaForGuestCompliance
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
    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq "enabled" }

        # Remove policies that require password change, as they are related to user risk and not MFA on signin
        $policies = $policies | Where-Object { $_.grantControls.builtInControls -notcontains 'passwordChange' }
        $policiesResult = New-Object System.Collections.ArrayList

        $GuestTypes = @( "internalGuest", "b2bCollaborationGuest", "b2bCollaborationMember", "b2bDirectConnectUser", "otherExternalUser", "serviceProvider" )

        $result = $false
        foreach ($policy in $policies) {
            try {
                # Check if all guest types are present in the policy
                $AllGuestTypesPresent = ( Compare-Object -ReferenceObject $GuestTypes -DifferenceObject ( $policy.conditions.users.includeGuestsOrExternalUsers.guestOrExternalUserTypes -split ',') -IncludeEqual -ExcludeDifferent -PassThru | Measure-Object | Select-Object -ExpandProperty Count ) -eq $GuestTypes.Count
            } catch {
                $AllGuestTypesPresent = $false
            }

            # Simplified logic for checking MFA requirements
            $RequiresMfa = $policy.grantControls.builtInControls -contains 'mfa' -or $policy.grantControls.authenticationStrength.requirementsSatisfied -contains 'mfa'
            $AppliesToGuests = $policy.conditions.users.includeUsers -contains "GuestsOrExternalUsers" -or $AllGuestTypesPresent
            $AppliesToAllUsers = $policy.conditions.users.includeUsers -contains "All"
            $AppliesToAllApps = $policy.conditions.applications.includeApplications -contains "All"
            $ExcludesAnyGuests = $null -ne $policy.conditions.users.excludeGuestsOrExternalUsers

            if ($RequiresMfa -and $AppliesToAllApps -and -not $ExcludesAnyGuests -and ($AppliesToGuests -or $AppliesToAllUsers)) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
            }

            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( $result ) {
        } else {
            $testResult = "No conditional access policy requires multi-factor authentication for guest accounts."
        }

        return $result
    } catch {
        return $false
    }

}
