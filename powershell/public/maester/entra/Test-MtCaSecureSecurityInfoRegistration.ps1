function Test-MtCaSecureSecurityInfoRegistration {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy securing security info registration.

    .Description
    Security info registration Conditional Access policy can secure the registration of security info for users in the tenant.

    A policy is considered a match when it is enabled and configured to secure security info registration from a trusted location only, i.e. it targets all users, includes the 'urn:user:registersecurityinfo' user action, applies to the browser (or all) client apps, includes all locations, and excludes at least one (trusted) location.

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
        foreach ($policy in $policies) {
            # Security info registration is performed through the browser, so a policy
            # scoped to the browser client app secures it just as well as one scoped to
            # all client apps. Requiring "all" rejected correctly scoped policies (#2105).
            $securesBrowserRegistration = $policy.conditions.clientAppTypes -contains "all" -or $policy.conditions.clientAppTypes -contains "browser"
            if (
                $policy.conditions.users.includeUsers -eq "All" -and
                $securesBrowserRegistration -and
                $policy.conditions.applications.includeUserActions -eq "urn:user:registersecurityinfo" -and
                $policy.conditions.locations.includeLocations -eq "All" -and
                $null -ne $policy.conditions.locations.excludeLocations
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
            $testResult = "No Conditional Access policy secures security info registration from a trusted location only. A matching policy must target all users, include the 'urn:user:registersecurityinfo' user action, apply to the browser (or all) client apps, include all locations, and exclude at least one (trusted) location."
        }
        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $false
    }
}
