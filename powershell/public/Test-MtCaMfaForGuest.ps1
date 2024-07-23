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

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
    # Remove policies that require password change, as they are related to user risk and not MFA on signin
    $policies = $policies | Where-Object { $_.grantcontrols.builtincontrols -notcontains 'passwordChange' }
    $policiesResult = New-Object System.Collections.ArrayList

    $GuestTypes = @( "internalGuest", "b2bCollaborationGuest", "b2bCollaborationMember", "b2bDirectConnectUser", "otherExternalUser", "serviceProvider" )

    $result = $false
    foreach ($policy in $policies) {
        try {
            # Check if all guest types are present in the policy and compare with the known count of the guest types
            $AllGuestTypesPresent = ( Compare-Object -ReferenceObject $GuestTypes -DifferenceObject ( $policy.conditions.users.includeGuestsOrExternalUsers.guestOrExternalUserTypes -split ',') -IncludeEqual -ExcludeDifferent -PassThru | Measure-Object | Select-Object -ExpandProperty Count ) -eq $GuestTypes.Count
        } catch {
            $AllGuestTypesPresent = $false
        }
        if ( ( $policy.grantcontrols.builtincontrols -contains 'mfa' `
                    -or $policy.grantcontrols.authenticationStrength.requirementsSatisfied -contains 'mfa' ) `
                -and ( $policy.conditions.users.includeUsers -eq "GuestsOrExternalUsers" `
                    -or $AllGuestTypesPresent ) `
                -and $policy.conditions.applications.includeApplications -eq "All" `
        ) {
            $result = $true
            $currentresult = $true
            $policiesResult.Add($policy) | Out-Null
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    if ( $result ) {
        $testResult = "The following conditional access policies require multi-factor authentication for guest accounts:`n`n%TestResult%"
    } else {
        $testResult = "No conditional access policy requires multi-factor authentication for guest accounts."
    }
    Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

    return $result
}