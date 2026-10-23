function Test-MtAndroidAppProtectionOfflineGracePeriod {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android app protection policy limits offline access to organization data.

    .DESCRIPTION
    Every revocation an administrator can perform on an unenrolled phone travels through the app
    protection check: disabling the account, removing the user from the assigned group, or issuing a
    selective wipe. The offline grace period is how long the managed app keeps opening organization
    data without that check. A device kept in airplane mode is a device that has not received any of
    those decisions.

    Two settings bound it. The offline grace period blocks access until the app can check in again,
    and the offline interval before wipe removes the organization's data from a device that never
    comes back.

    This test passes if at least one Android app protection policy that is assigned to a group sets an
    offline grace period of at most 12 hours and wipes organization data after at most 90 days
    offline.

    .EXAMPLE
    Test-MtAndroidAppProtectionOfflineGracePeriod

    Returns true if at least one assigned Android app protection policy limits offline access to organization data.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidAppProtectionOfflineGracePeriod
    #>
    [MaesterTest(
        Id = 'MT.1248',
        Title = 'Ensure Android app protection policy limits offline access to organization data.',
        Product = 'intune',
        Feature = 'app-protection',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('nist-800-53-r5:AC-12', 'nist-800-53-r5:AC-19'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose "Querying Android app protection policies..."
        $policies = Get-MtAppProtectionPolicy -Platform Android
        if ($null -eq $policies) {
            # The helper could not read the data at all: most commonly the DeviceManagementApps.Read.All
            # scope is missing from the connection, or Intune RBAC returned a 403.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No Android app protection policies were found in Intune.`n`n"
            $testResultMarkdown += "Without an Android app protection policy, a managed app on an offline phone never re-checks whether the user still has access. Create an Android app protection policy, set the offline grace period under **Conditional launch** and assign it."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # The setting and the assignment are one condition on one policy, so they are evaluated
        # together. Two separate tests cannot express the conjunction: a policy that configures the
        # setting but is not assigned, and a policy that is assigned but does not configure it, would
        # both pass while no user is covered.
        # A threshold that was never configured comes back as $null, not 0, and in PowerShell
        # $null -le <n> is $true. Each threshold is therefore checked for $null before it is compared,
        # or an unconfigured policy would pass as if it were under the limit.
        # Both values arrive as ISO 8601 durations ("PT12H", "P90D"), which the helper also returns
        # parsed. Compare the parsed numbers: as strings, 'PT12H' -le 'PT2H' is $true, which would
        # read twelve hours as inside a two-hour limit.
        $compliant = @($policies | Where-Object {
                $null -ne $_.OfflineBeforeAccessCheckHours -and
                $_.OfflineBeforeAccessCheckHours -gt 0 -and $_.OfflineBeforeAccessCheckHours -le 12 -and
                $null -ne $_.OfflineBeforeWipeDays -and
                $_.OfflineBeforeWipeDays -gt 0 -and $_.OfflineBeforeWipeDays -le 90 -and
                $_.IsAssigned
            })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) Android app protection policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Offline grace period | Offline interval before wipe | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $graceState = if ($null -eq $policy.OfflineBeforeAccessCheckHours) { 'Not configured' } else { "$($policy.OfflineBeforeAccessCheckHours) h" }
            $wipeState = if ($null -eq $policy.OfflineBeforeWipeDays) { 'Not configured' } else { "$($policy.OfflineBeforeWipeDays) d" }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $graceState | $wipeState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android app protection policy limits offline access to organization data."
            $gaps = @($policies | Where-Object { $_.IsAssigned -and -not ($null -ne $_.OfflineBeforeAccessCheckHours -and $_.OfflineBeforeAccessCheckHours -gt 0 -and $_.OfflineBeforeAccessCheckHours -le 12 -and $null -ne $_.OfflineBeforeWipeDays -and $_.OfflineBeforeWipeDays -gt 0 -and $_.OfflineBeforeWipeDays -le 90) })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
                $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
            }
        } else {
            $unassigned = @($policies | Where-Object { ($null -ne $_.OfflineBeforeAccessCheckHours -and $_.OfflineBeforeAccessCheckHours -gt 0 -and $_.OfflineBeforeAccessCheckHours -le 12 -and $null -ne $_.OfflineBeforeWipeDays -and $_.OfflineBeforeWipeDays -gt 0 -and $_.OfflineBeforeWipeDays -le 90) -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
            } else {
                $testResultMarkdown += "`nNo Android app protection policy bounds offline access. A phone that stays offline keeps opening organization data without ever receiving a revocation, an account disable or a selective wipe."
            }
        }

        $disagreeing = @($policies | Where-Object { $_.AssignmentSignalsDisagree })
        if ($disagreeing.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** on $($disagreeing.Count) policy/policies the expanded assignments and the "
            $testResultMarkdown += "isAssigned property disagree. They are counted as assigned; review their assignments in Intune."
        }


        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}
