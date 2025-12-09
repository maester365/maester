<#
    .Synopsis
    Checks if the tenant has at least one conditional access policy requiring multifactor authentication for all guest users.

    .Description
    MFA for all users conditional access policy can be used to require MFA for all guest users in the tenant.

    Learn more:
    https://aka.ms/CATemplatesGuest

    .Example
    Test-MtCaMfaForGuest

.LINK
    https://maester.dev/docs/commands/Test-MtCaMfaForGuest
#>
function Test-MtCaMfaForGuest {
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
            $testResult = "The following conditional access policies require multi-factor authentication for guest accounts:`n`n%TestResult%"
        } else {
            $testResult = "No conditional access policy requires multi-factor authentication for guest accounts."
        }

        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess
        return $result
    } catch {
        Add-MtTestResultDetail -Error $_ -GraphObjectType ConditionalAccess
        return $false
    }
}
