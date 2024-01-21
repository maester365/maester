<#
    .Synopsis
    Checks if the tenant has at least one conditional access policy requiring multifactor authentication for all guest users.

    .Description
    MFA for all users conditional access policy can be used to require MFA for all guest users in the tenant.

    Learn more:
    https://aka.ms/CATemplatesGuest

    .Example
    Test-MtCaMfaForGuests
#>

Function Test-MtCaMfaForGuests {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Set-StrictMode -Off
    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }
    # Remove policies that require password change, as they are related to user risk and not MFA on signin
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -notcontains 'passwordChange' }

    $GuestTypes = @( "internalGuest", "b2bCollaborationGuest", "b2bCollaborationMember", "b2bDirectConnectUser", "otherExternalUser", "serviceProvider" )

    $result = $false
    foreach ($policy in $policies) {
        try {
            # Check if all guest types are present in the policy and compare with the known count of the guest types
            $AllGuestTypesPresent = ( Compare-Object -ReferenceObject $GuestTypes -DifferenceObject ( $policy.conditions.users.includeGuestsOrExternalUsers.guestOrExternalUserTypes -split ',') -IncludeEqual -ExcludeDifferent -PassThru | Measure-Object | Select-Object -ExpandProperty Count ) -eq $GuestTypes.Count
        } catch {
            $AllGuestTypesPresent = $false
        }
        if ( ( $policy.grantcontrols.builtincontrols -contains 'mfa' -or $policy.grantcontrols.authenticationStrength.requirementsSatisfied -contains 'mfa' ) `
                -and ( $policy.conditions.users.includeUsers -eq "GuestsOrExternalUsers"  `
                    -or $AllGuestTypesPresent ) `
                -and $policy.conditions.applications.includeApplications -eq "All" ) {
            $result = $true
            $currentresult = $true
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }
    Set-StrictMode -Version Latest

    return $result
}