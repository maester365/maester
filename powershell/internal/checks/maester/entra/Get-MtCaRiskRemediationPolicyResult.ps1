function Get-MtCaRiskRemediationPolicyResult {
    <#
    .SYNOPSIS
    Evaluates the Conditional Access policies that require risk remediation for risky users.

    .DESCRIPTION
    Shared evaluation of MT.1253, also used by MT.1013 to skip the password change check when MT.1253's
    requirement is met. A policy qualifies when it:
    - is enabled,
    - includes all users, excluding only emergency access accounts and the guest/external-user selector,
    - targets all resources,
    - is scoped to every user risk level from MinimumUserRiskLevel up to high, and
    - requires the riskRemediation grant control.

    Emergency access comes from the EmergencyAccessAccounts setting. Without the setting, a user or group excluded
    from every Conditional Access policy that targets users (at least two) is taken as emergency access, as MT.1005
    does. Get-MtEmergencyAccessAccount throws when a configured entry cannot be resolved.

    Returns one object with the policies, a report row per risk remediation policy and whether any policy qualifies.

    .EXAMPLE
    (Get-MtCaRiskRemediationPolicyResult).Pass

    Returns $true when at least one policy requires risk remediation for high-risk users as MT.1253 requires.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Lowest user risk level that a qualifying policy must cover; every higher level must be covered too.
        [ValidateSet('high', 'medium', 'low')]
        [string] $MinimumUserRiskLevel = 'high'
    )

    $requiredRiskLevels = switch ($MinimumUserRiskLevel) {
        'low' { @('low', 'medium', 'high') }
        'medium' { @('medium', 'high') }
        default { @('high') }
    }

    $policies = @(Get-MtConditionalAccessPolicy)
    $riskRemediationPolicies = @($policies | Where-Object {
            @($_.grantControls.builtInControls) -contains 'riskRemediation'
        } | Sort-Object -Property displayName)

    # Emergency access exclusions are allowed. They come from the EmergencyAccessAccounts setting; the helper fails if
    # a configured object cannot be resolved. Without the setting, a user or group excluded from every Conditional
    # Access policy that targets users is taken as emergency access, as MT.1005 does. One policy is not enough to
    # tell an emergency access account from any other exclusion.
    $emergencyAccess = @(Get-MtEmergencyAccessAccount)
    $emergencyUserIds = @($emergencyAccess | Where-Object { $_.Type -eq 'user' -and $_.ObjectId } | ForEach-Object { $_.ObjectId })
    $emergencyGroupIds = @($emergencyAccess | Where-Object { $_.Type -eq 'group' -and $_.ObjectId } | ForEach-Object { $_.ObjectId })
    $emergencyAccessDetected = $false
    if ($emergencyAccess.Count -eq 0) {
        $userPolicies = @($policies | Where-Object {
                -not $_.conditions.applications.includeAuthenticationContextClassReferences -and
                -not $_.conditions.clientApplications.includeServicePrincipals -and
                -not $_.conditions.clientApplications.includeAgentIdServicePrincipals
            })
        if ($userPolicies.Count -ge 2) {
            $excludedFromAll = {
                param([string] $Property)
                @($userPolicies | ForEach-Object { @($_.conditions.users.$Property | Where-Object { $_ -and $_ -ne 'GuestsOrExternalUsers' } | Select-Object -Unique) } |
                        Group-Object | Where-Object { $_.Count -eq $userPolicies.Count } | ForEach-Object { $_.Name })
            }
            $emergencyUserIds = & $excludedFromAll 'excludeUsers'
            $emergencyGroupIds = & $excludedFromAll 'excludeGroups'
            $emergencyAccessDetected = ($emergencyUserIds.Count + $emergencyGroupIds.Count) -gt 0
        }
    }

    $report = foreach ($policy in $riskRemediationPolicies) {
        $userRiskLevels = @($policy.conditions.userRiskLevels | Where-Object { $_ })
        $missingRiskLevels = @($requiredRiskLevels | Where-Object { $_ -notin $userRiskLevels })
        $users = $policy.conditions.users
        # Both the legacy GuestsOrExternalUsers token and excludeGuestsOrExternalUsers select only guest/external
        # users, for whom risk remediation is unsupported. Neither exempts arbitrary workforce users or roles.
        $unapprovedUsers = @($users.excludeUsers | Where-Object { $_ -and $_ -ne 'GuestsOrExternalUsers' -and $_ -notin $emergencyUserIds })
        $unapprovedGroups = @($users.excludeGroups | Where-Object { $_ -and $_ -notin $emergencyGroupIds })
        $excludedRoles = @($users.excludeRoles | Where-Object { $_ })
        $checks = [ordered]@{
            'Enabled'                       = $policy.state -eq 'enabled'
            'All users'                     = @($policy.conditions.users.includeUsers) -contains 'All'
            'Only approved user exclusions' = ($unapprovedUsers.Count + $unapprovedGroups.Count + $excludedRoles.Count) -eq 0
            'All resources'                 = @($policy.conditions.applications.includeApplications) -contains 'All'
            "User risk $($requiredRiskLevels -join ', ')" = $missingRiskLevels.Count -eq 0
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        $exclusionCount = @($policy.conditions.users.excludeUsers | Where-Object { $_ }).Count +
            @($policy.conditions.users.excludeGroups | Where-Object { $_ }).Count +
            @($policy.conditions.users.excludeRoles | Where-Object { $_ }).Count +
            $(if ($users.excludeGuestsOrExternalUsers) { 1 } else { 0 })

        [pscustomobject]@{
            Policy         = $policy
            UserRiskLevels = if ($userRiskLevels.Count -gt 0) { $userRiskLevels -join ', ' } else { 'None' }
            Exclusions     = $exclusionCount
            Failed         = $failed -join ', '
            Pass           = $failed.Count -eq 0
        }
    }
    $report = @($report)

    [pscustomobject]@{
        RequiredRiskLevels      = $requiredRiskLevels
        Policies                = $policies
        Report                  = $report
        Pass                    = @($report | Where-Object { $_.Pass }).Count -gt 0
        EmergencyUserIds        = @($emergencyUserIds)
        EmergencyGroupIds       = @($emergencyGroupIds)
        EmergencyAccessDetected = $emergencyAccessDetected
    }
}
