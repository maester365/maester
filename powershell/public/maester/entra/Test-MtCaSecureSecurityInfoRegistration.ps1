function Test-MtCaSecureSecurityInfoRegistration {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy securing security info registration.

    .Description
    Security info registration Conditional Access policy can secure the registration of security info for users in the tenant.

    A policy is considered a match when it is enabled and configured to secure security info registration from a trusted location only, i.e. it targets all users, includes the 'urn:user:registersecurityinfo' user action, applies to all client apps, includes all locations, and excludes at least one (trusted) location.

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
        foreach ($policy in $policies) {
            if (
                $policy.conditions.users.includeUsers -eq "All" -and
                $policy.conditions.clientAppTypes -eq "all" -and
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
            $testResult = "No Conditional Access policy secures security info registration from a trusted location only. A matching policy must target all users, include the 'urn:user:registersecurityinfo' user action, apply to all client apps, include all locations, and exclude at least one (trusted) location.`n`nIf you have a policy that looks correct but is scoped to the browser client app only, that is why it is not matched. Security info registration is also triggered from native apps such as Microsoft Authenticator, so the policy must apply to all client apps to cover every registration path."
        }
        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $false
    }
}
