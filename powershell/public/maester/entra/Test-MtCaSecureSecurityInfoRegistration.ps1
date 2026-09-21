function Test-MtCaSecureSecurityInfoRegistration {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy securing security info registration.

    .Description
    Security info registration Conditional Access policy can secure the registration of security info for users in the tenant.

    A policy is considered a match when it is enabled and configured to secure security info registration from a trusted location only, i.e. it targets all users, includes the 'urn:user:registersecurityinfo' user action, applies to all client apps, includes all locations, and excludes 'AllTrusted' or a named location marked as trusted.

    The excluded location has to be trusted for the policy to match. Excluding an untrusted named location leaves registration unprotected from everywhere that location covers, so it does not count. Only IP named locations can be marked trusted - country named locations have no trust concept, and an exclusion that no longer resolves to an existing location does not count either.

    A policy scoped to the browser client app only does not match. Security info is not registered through the browser alone - the user action is also triggered from native apps such as Microsoft Authenticator when an authentication method is added - so the policy has to apply to all client apps to cover every registration path. This is why the user action is selected differently from a standard cloud app, and it is the configuration Microsoft recommends.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-registration

    .Example
    Test-MtCaSecureSecurityInfoRegistration

    .LINK
    https://maester.dev/docs/commands/Test-MtCaSecureSecurityInfoRegistration
    #>
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

        $result = $false
        $trustedLocationIds = @()
        $trustedLocationsLoaded = $false

        foreach ($policy in $policies) {
            # An exclusion only secures registration if the excluded location is actually trusted.
            # 'AllTrusted' says so outright; any other exclusion is a named location ID that has to
            # be resolved, because excluding an untrusted location leaves the control unenforced.
            # @($null) is a one-element array, so filter empties out rather than counting them
            # as an exclusion and resolving named locations for a policy that excludes nothing.
            $excludedLocations = @($policy.conditions.locations.excludeLocations | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $excludesTrustedLocation = $false
            if ($excludedLocations -contains 'AllTrusted') {
                $excludesTrustedLocation = $true
            } elseif ($excludedLocations.Count -gt 0) {
                if (-not $trustedLocationsLoaded) {
                    $trustedLocationIds = @(Get-MtTrustedNamedLocationId)
                    $trustedLocationsLoaded = $true
                }
                $excludesTrustedLocation = @($excludedLocations | Where-Object { $_ -in $trustedLocationIds }).Count -gt 0
            }

            if (
                $policy.conditions.users.includeUsers -eq "All" -and
                $policy.conditions.clientAppTypes -eq "all" -and
                $policy.conditions.applications.includeUserActions -eq "urn:user:registersecurityinfo" -and
                $policy.conditions.locations.includeLocations -eq "All" -and
                $excludesTrustedLocation
            ) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( $result ) {
            $testResult = "The following Conditional Access policies secure security info registration.`n`n%TestResult%"
        } else {
            $testResult = "No Conditional Access policy secures security info registration from a trusted location only. A matching policy must target all users, include the 'urn:user:registersecurityinfo' user action, apply to all client apps, include all locations, and exclude 'AllTrusted' or a named location marked as trusted.`n`nTwo configurations are commonly mistaken for a match:`n`n  - A policy scoped to the browser client app only. Security info registration is also triggered from native apps such as Microsoft Authenticator, so the policy must apply to all client apps to cover every registration path.`n  - A policy that excludes a location that is not marked as trusted. Only IP named locations can be trusted, so excluding a country, or an untrusted named location, leaves registration unprotected from everywhere that location covers."
        }
        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $false
    }
}
