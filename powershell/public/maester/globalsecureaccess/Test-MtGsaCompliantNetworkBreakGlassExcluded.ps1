function Test-MtGsaCompliantNetworkBreakGlassExcluded {
    <#
    .SYNOPSIS
        Checks that every Compliant Network Conditional Access policy excludes the emergency access (break-glass) accounts.

    .DESCRIPTION
        A Conditional Access policy that enforces the Global Secure Access Compliant Network control
        blocks access when the session is not on a compliant network. If such a policy does not exclude
        the emergency access (break-glass) accounts, it can lock out the very accounts needed to recover
        the tenant. This check verifies that every enabled Compliant Network enforcement policy excludes
        all configured break-glass accounts and groups.

        Emergency access accounts are read from the EmergencyAccessAccounts setting in maester-config.json.

    .EXAMPLE
        Test-MtGsaCompliantNetworkBreakGlassExcluded

        Returns $true if every Compliant Network enforcement policy excludes the break-glass accounts.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaCompliantNetworkBreakGlassExcluded
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    if ((Get-MtLicenseInformation -Product EntraID) -eq 'Free') {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $compliantNetworkPolicies = Get-MtCompliantNetworkPolicy
        if (-not $compliantNetworkPolicies) {
            Add-MtTestResultDetail -Result 'No enabled Compliant Network enforcement policy was found, so there is nothing to evaluate.'
            return $null
        }

        $emergencyAccounts = Get-MtEmergencyAccessAccount
        if (-not $emergencyAccounts) {
            Add-MtTestResultDetail -Result 'No emergency access accounts are configured in maester-config.json (EmergencyAccessAccounts), so break-glass exclusion cannot be verified.'
            return $null
        }

        # Resolve the parent groups each break-glass account belongs to (transitively), so an account
        # excluded via (nested) group membership - not just a direct user/group exclusion - is correctly
        # recognised. Both user and group accounts are resolved (a break-glass group can itself be a
        # member of an excluded group). Graph failures propagate to the outer catch so the check reports
        # an indeterminate result rather than a false pass.
        $accountGroupIds = @{}
        foreach ($account in $emergencyAccounts) {
            $endpoint = if ($account.Type -eq 'group') { "groups/$($account.ObjectId)/transitiveMemberOf" } else { "users/$($account.ObjectId)/transitiveMemberOf" }
            $memberOf = Invoke-MtGraphRequest -RelativeUri $endpoint -Select 'id' -ErrorAction Stop
            $accountGroupIds[$account.ObjectId] = @($memberOf.id)
        }

        $policiesMissingExclusion = @()
        foreach ($policy in $compliantNetworkPolicies) {
            $excludeUsers  = @($policy.conditions.users.excludeUsers)
            $excludeGroups = @($policy.conditions.users.excludeGroups)

            $uncovered = @()
            foreach ($account in $emergencyAccounts) {
                $id = $account.ObjectId
                $directlyExcluded = ($id -in $excludeUsers) -or ($id -in $excludeGroups)
                $excludedViaGroup = @($accountGroupIds[$id] | Where-Object { $_ -in $excludeGroups }).Count -gt 0
                if (-not ($directlyExcluded -or $excludedViaGroup)) {
                    $uncovered += $account.DisplayName
                }
            }

            if ($uncovered.Count -gt 0) {
                $policiesMissingExclusion += [pscustomobject]@{ DisplayName = $policy.displayName; Uncovered = ($uncovered -join ', ') }
            }
        }

        $result = ($policiesMissingExclusion.Count -eq 0)
        if ($result) {
            $testResult = "Well done. Every Compliant Network enforcement policy excludes the emergency access (break-glass) accounts (directly or via an excluded group).`n`n"
        } else {
            $testResult = "These Compliant Network enforcement policies do **not** exclude all break-glass accounts (directly or via an excluded group) - lock-out risk:`n`n| Policy | Not excluded |`n| --- | --- |`n"
            foreach ($policy in $policiesMissingExclusion) {
                $testResult += "| $($policy.DisplayName) | $($policy.Uncovered) |`n"
            }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
