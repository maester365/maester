function Test-MtAndroidAppProtectionMinimumVersions {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android app protection policy requires a minimum OS and app version.

    .DESCRIPTION
    On an unenrolled phone, the conditional launch rules of an app protection policy are the only
    lever the organization has over how old the platform underneath its data is allowed to be. There
    is no compliance evaluation, no update ring and no device inventory: either the policy refuses to
    open the app on an outdated Android or app version, or it does not.

    Two versions matter. The Android version is the platform whose protections the whole app
    protection model rests on, and the app version is the Intune App SDK that enforces the policy; an
    old app can predate the settings the policy relies on.

    Android adds a third, the minimum security patch level, which is the more precise signal on a
    fleet where two phones on the same Android version can be a year apart in patches. It is reported
    in the results but is not required for a pass, so that the requirement stays the same on both
    platforms.

    This test passes if at least one Android app protection policy that is assigned to a group sets
    both a minimum OS version and a minimum app version.

    .EXAMPLE
    Test-MtAndroidAppProtectionMinimumVersions

    Returns true if at least one assigned Android app protection policy requires a minimum OS and app version.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidAppProtectionMinimumVersions
    #>
    [MaesterTest(
        Id = 'MT.TBD-30',
        Title = 'Ensure Android app protection policy requires a minimum OS and app version.',
        Product = 'intune',
        Feature = 'app-protection',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1203', 'T1068'),
        Control = ('nist-800-53-r5:SI-2', 'nist-800-53-r5:AC-19'),
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
            $testResultMarkdown += "Without an Android app protection policy, organization data opens on any Android version the phone happens to run. Create an Android app protection policy, set a minimum OS and app version under **Conditional launch** and assign it."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # The setting and the assignment are one condition on one policy, so they are evaluated
        # together. Two separate tests cannot express the conjunction: a policy that configures the
        # setting but is not assigned, and a policy that is assigned but does not configure it, would
        # both pass while no user is covered.
        # An unconfigured version is an empty string or $null, never a low version number. Comparing
        # it against a target would be a string comparison against nothing, so presence is what is
        # checked here and the chosen floor is left to the organization.
        $compliant = @($policies | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.MinimumRequiredOsVersion) -and
                -not [string]::IsNullOrWhiteSpace($_.MinimumRequiredAppVersion) -and
                $_.IsAssigned
            })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) Android app protection policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Minimum Android version | Minimum app version | Minimum patch level | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $osState = if ([string]::IsNullOrWhiteSpace($policy.MinimumRequiredOsVersion)) { 'Not configured' } else { $policy.MinimumRequiredOsVersion }
            $appState = if ([string]::IsNullOrWhiteSpace($policy.MinimumRequiredAppVersion)) { 'Not configured' } else { $policy.MinimumRequiredAppVersion }
            $patchState = if ([string]::IsNullOrWhiteSpace($policy.MinimumRequiredPatchVersion)) { 'Not configured' } else { $policy.MinimumRequiredPatchVersion }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $osState | $appState | $patchState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android app protection policy requires a minimum OS and app version."
            $gaps = @($policies | Where-Object { $_.IsAssigned -and -not (-not [string]::IsNullOrWhiteSpace($_.MinimumRequiredOsVersion) -and -not [string]::IsNullOrWhiteSpace($_.MinimumRequiredAppVersion)) })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
                $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
            }
        } else {
            $unassigned = @($policies | Where-Object { (-not [string]::IsNullOrWhiteSpace($_.MinimumRequiredOsVersion) -and -not [string]::IsNullOrWhiteSpace($_.MinimumRequiredAppVersion)) -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
            } else {
                $testResultMarkdown += "`nNo Android app protection policy requires a minimum OS and app version. Organization data opens in the managed apps on any Android version the device happens to run, including versions that stopped receiving security patches years ago."
            }
        }

        $disagreeing = @($policies | Where-Object { $_.AssignmentSignalsDisagree })
        if ($disagreeing.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** on $($disagreeing.Count) policy/policies the expanded assignments and the "
            $testResultMarkdown += "isAssigned property disagree. They are counted as assigned; review their assignments in Intune."
        }

        $noPatchFloor = @($policies | Where-Object { $_.IsAssigned -and [string]::IsNullOrWhiteSpace($_.MinimumRequiredPatchVersion) })
        if ($noPatchFloor.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($noPatchFloor.Count) assigned policy/policies set no minimum security patch "
            $testResultMarkdown += "level. On Android two phones on the same OS version can be a year apart in patches, so consider "
            $testResultMarkdown += "adding **Min Android security patch level** as well. It is not required for this test to pass."
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
