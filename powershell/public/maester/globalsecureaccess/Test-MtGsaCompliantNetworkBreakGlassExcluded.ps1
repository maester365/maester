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
        $emergencyAccountIds = @($emergencyAccounts.ObjectId)

        $policiesMissingExclusion = @()
        foreach ($policy in $compliantNetworkPolicies) {
            $excludedPrincipals = @($policy.conditions.users.excludeUsers) + @($policy.conditions.users.excludeGroups)
            $isCovered = @($emergencyAccountIds | Where-Object { $_ -in $excludedPrincipals }).Count -eq $emergencyAccountIds.Count
            if (-not $isCovered) {
                $policiesMissingExclusion += $policy
            }
        }

        $result = ($policiesMissingExclusion.Count -eq 0)
        if ($result) {
            $testResult = "Well done. Every Compliant Network enforcement policy excludes the emergency access (break-glass) accounts.`n`n"
        } else {
            $testResult = "These Compliant Network enforcement policies do **not** exclude all break-glass accounts (lock-out risk):`n`n"
            foreach ($policy in $policiesMissingExclusion) {
                $testResult += "* $($policy.displayName)`n"
            }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
