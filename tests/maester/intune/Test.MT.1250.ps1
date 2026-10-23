function Test-MtAndroidAppProtectionScreenCapture {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android app protection policy blocks screen capture of organization data.

    .DESCRIPTION
    A screenshot is a copy of organization data that leaves through none of the data transfer paths a
    policy restricts. It lands in the device gallery, which on a personal phone is usually syncing to
    a personal cloud account, and it is readable by any app the user has granted storage or
    screen-recording access to.

    Blocking screen capture sets the platform flag that also hides the app's content from Android
    screen recording and from the recent-apps preview. It is the only such setting in the app
    protection model that the platform enforces for the whole app window rather than for a copy
    action.

    This check exists only for Android, because screenCaptureBlocked is an Android-only property. The iOS
    policy type carries a newer screenCaptureConfigurationState, which is optional in the beta schema and
    whose behaviour is not verified here, so no iOS counterpart is claimed.

    This test passes if at least one Android app protection policy that is assigned to a group blocks
    screen capture.

    .EXAMPLE
    Test-MtAndroidAppProtectionScreenCapture

    Returns true if at least one assigned Android app protection policy blocks screen capture.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidAppProtectionScreenCapture
    #>
    [MaesterTest(
        Id = 'MT.1250',
        Title = 'Ensure Android app protection policy blocks screen capture of organization data.',
        Product = 'intune',
        Feature = 'app-protection',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1113',
        Control = ('nist-800-53-r5:AC-4', 'nist-800-53-r5:AC-19'),
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
            $testResultMarkdown += "Without an Android app protection policy, any screen of organization data can be captured into the device gallery. Create an Android app protection policy, set **Screen capture and Google Assistant** to **Block** and assign it."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # The setting and the assignment are one condition on one policy, so they are evaluated
        # together. Two separate tests cannot express the conjunction: a policy that configures the
        # setting but is not assigned, and a policy that is assigned but does not configure it, would
        # both pass while no user is covered.
        $compliant = @($policies | Where-Object {
                $_.ScreenCaptureBlocked -and
                $_.IsAssigned
            })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) Android app protection policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Screen capture | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $captureState = if ($policy.ScreenCaptureBlocked) { 'Blocked' } else { 'Allowed' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $captureState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android app protection policy blocks screen capture of organization data."
            $gaps = @($policies | Where-Object { $_.IsAssigned -and -not ($_.ScreenCaptureBlocked) })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
                $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
            }
        } else {
            $unassigned = @($policies | Where-Object { ($_.ScreenCaptureBlocked) -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
            } else {
                $testResultMarkdown += "`nNo Android app protection policy blocks screen capture. A screenshot copies organization data past every data transfer restriction the policy sets, into a gallery that on a personal phone is usually syncing to a personal cloud account."
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
