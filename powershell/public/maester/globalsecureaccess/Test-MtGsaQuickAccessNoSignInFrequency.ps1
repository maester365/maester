function Test-MtGsaQuickAccessNoSignInFrequency {
    <#
    .SYNOPSIS
        Checks that no Conditional Access sign-in frequency control applies to the Global Secure Access Quick Access app.

    .DESCRIPTION
        When Private DNS is hosted on the Quick Access application, the Global Secure Access client's DNS
        queries authenticate against the Quick Access app and are evaluated by Conditional Access. A
        sign-in frequency session control then re-triggers on those frequent DNS lookups, causing
        unexpected and repeated authentication prompts. Microsoft therefore recommends not applying a
        sign-in frequency control to Quick Access.

        This is an operational / user-experience hygiene check, not a security gap. An enabled sign-in
        frequency policy that targets Quick Access is reported as Fail, except when it falls into a
        category that does not drive routine DNS prompts, which is surfaced for Review instead:

        - Role-only  : scoped only to directory roles (e.g. admins), who typically do not use Private Access.
        - Guest      : scoped to guest / external users, who very rarely use Private Access.
        - Risk-gated : has a user- or sign-in-risk condition, so the control only applies under elevated risk.
        - Browser    : limited to the 'browser' client app type; Private Access traffic is not browser-based.

        Reviewed, accepted exceptions can be allow-listed by policy id or display name via the
        'GsaQuickAccessSignInFrequencyAllowedPolicies' global setting (maester-config.json); those are
        reported as Accepted and never fail.

        Remediation for a Fail is to exclude the Quick Access app from the sign-in frequency policy - not
        to remove the control organization-wide.

    .EXAMPLE
        Test-MtGsaQuickAccessNoSignInFrequency

        Returns $true if no sign-in frequency policy applies to Quick Access outside the allowed categories.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaQuickAccessNoSignInFrequency
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # Conditional Access policies (by id or displayName) that are reviewed, accepted exceptions and
        # should never fail this check. Defaults to the 'GsaQuickAccessSignInFrequencyAllowedPolicies'
        # GlobalSetting in maester-config.json.
        [string[]] $AllowedPolicies
    )

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    if ((Get-MtLicenseInformation -Product EntraID) -eq 'Free') {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    # Robust emptiness test: @($null).Count is 1, so filter out null/empty entries before counting.
    function Test-HasValue ($Value) { return (@($Value).Where({ $_ }).Count -gt 0) }

    try {
        $quickAccess = Get-MtPrivateAccessApplication | Where-Object { $_.tags -contains 'NetworkAccessQuickAccessApplication' } | Select-Object -First 1
        if (-not $quickAccess) {
            Add-MtTestResultDetail -Result 'No Quick Access application was found (Global Secure Access Private Access is not configured).'
            return $null
        }
        $quickAccessAppId = $quickAccess.appId

        if (-not $AllowedPolicies) {
            $AllowedPolicies = @(Get-MtMaesterConfigGlobalSetting -SettingName 'GsaQuickAccessSignInFrequencyAllowedPolicies')
        }
        $AllowedPolicies = @($AllowedPolicies | Where-Object { $_ })

        # Enabled sign-in-frequency policies that target the Quick Access app (directly or via All resources).
        $sifQaPolicies = Get-MtConditionalAccessPolicy | Where-Object {
            $_.state -eq 'enabled' -and
            $_.sessionControls.signInFrequency.isEnabled -eq $true -and
            (
                (@($_.conditions.applications.includeApplications) -contains $quickAccessAppId) -or
                (
                    (@($_.conditions.applications.includeApplications) -contains 'All') -and
                    (@($_.conditions.applications.excludeApplications) -notcontains $quickAccessAppId)
                )
            )
        }

        $failPolicies = @()
        $reviewPolicies = @()   # objects: @{ Policy = ..; Reason = .. }
        $acceptedPolicies = @()

        foreach ($policy in $sifQaPolicies) {
            $conditions = $policy.conditions
            $users = $conditions.users

            # Accepted: reviewed exception on the allow-list (match id or display name, trim/case-insensitive).
            $isAllowed = @($AllowedPolicies | Where-Object {
                ($_.Trim() -ieq [string]$policy.id) -or ($_.Trim() -ieq ([string]$policy.displayName).Trim())
            }).Count -gt 0
            if ($isAllowed) { $acceptedPolicies += $policy; continue }

            # Risk-gated: control only applies under elevated risk, not on routine DNS.
            if ((Test-HasValue $conditions.userRiskLevels) -or (Test-HasValue $conditions.signInRiskLevels) -or (Test-HasValue $conditions.servicePrincipalRiskLevels)) {
                $reviewPolicies += [pscustomobject]@{ Policy = $policy; Reason = 'risk-gated (control only applies under elevated risk)' }
                continue
            }

            # Guest / external-user scoped: guests very rarely use Private Access.
            if (($null -ne $users.includeGuestsOrExternalUsers) -or (@($users.includeUsers) -contains 'GuestsOrExternalUsers')) {
                $reviewPolicies += [pscustomobject]@{ Policy = $policy; Reason = 'guest / external-user scoped' }
                continue
            }

            # Browser-only: Private Access / Quick Access traffic is a tunneled non-browser flow.
            $clientAppTypes = @($conditions.clientAppTypes | Where-Object { $_ })
            if (($clientAppTypes.Count -gt 0) -and (@($clientAppTypes | Where-Object { $_ -ne 'browser' }).Count -eq 0)) {
                $reviewPolicies += [pscustomobject]@{ Policy = $policy; Reason = 'browser-only client app types (Private Access traffic is not browser-based)' }
                continue
            }

            # Role-only: scoped to directory roles (e.g. admins) with no users or groups.
            if ((Test-HasValue $users.includeRoles) -and -not (Test-HasValue $users.includeUsers) -and -not (Test-HasValue $users.includeGroups)) {
                $reviewPolicies += [pscustomobject]@{ Policy = $policy; Reason = 'directory-role scoped (users who typically do not use Private Access)' }
                continue
            }

            $failPolicies += $policy
        }

        $result = (@($failPolicies).Count -eq 0)

        if ($result) {
            $testResult = "Well done. No enabled sign-in frequency Conditional Access control applies to the Quick Access app outside the accepted categories.`n`n"
        } else {
            $testResult = "These enabled Conditional Access policies apply a **sign-in frequency** control to the Quick Access app. Private DNS lookups can re-trigger authentication prompts - **exclude the Quick Access app** from each policy (keep the control for everything else):`n`n"
            foreach ($policy in $failPolicies) { $testResult += "* $($policy.displayName)`n" }
        }

        if (@($reviewPolicies).Count -gt 0) {
            $testResult += "`n**Review (not failing):** these apply a sign-in frequency to Quick Access but are unlikely to prompt on routine DNS. Confirm and, if warranted, exclude Quick Access here too or allow-list them:`n`n"
            foreach ($entry in $reviewPolicies) { $testResult += "* $($entry.Policy.displayName) - _$($entry.Reason)_`n" }
        }

        if (@($acceptedPolicies).Count -gt 0) {
            $testResult += "`n**Accepted (allow-listed):** reviewed exceptions from ``GsaQuickAccessSignInFrequencyAllowedPolicies``:`n`n"
            foreach ($policy in $acceptedPolicies) { $testResult += "* $($policy.displayName)`n" }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
