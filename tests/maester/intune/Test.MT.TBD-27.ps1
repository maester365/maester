function Test-MtAndroidAppProtectionPinPolicy {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android app protection policy requires a strong app PIN.

    .DESCRIPTION
    An app protection policy applies to a phone the organization never enrolled. On such a phone the
    app PIN is the only gate between whoever is holding the device and the organization's mail, files
    and chats inside Outlook, Teams and the Office apps. There is no device lock the organization can
    require and no remote lock it can trigger.

    A PIN that is required but four digits long and retried without limit is a lock with the key left
    beside it. Three settings together make it a control: the PIN itself, a length that resists
    guessing, and a retry limit that wipes the organization's data before the guessing succeeds.

    The three are read from the same policy. Intune returns a minimum PIN length and a retry limit
    whether or not a PIN is required, so a policy can carry a six-character minimum while the PIN is
    switched off.

    This test passes if at least one Android app protection policy that is assigned to a group
    requires a PIN, blocks simple PINs, requires at least 6 characters and acts after at most 5 failed
    attempts.

    .EXAMPLE
    Test-MtAndroidAppProtectionPinPolicy

    Returns true if at least one assigned Android app protection policy requires a strong app PIN.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidAppProtectionPinPolicy
    #>
    [MaesterTest(
        Id = 'MT.TBD-27',
        Title = 'Ensure Android app protection policy requires a strong app PIN.',
        Product = 'intune',
        Feature = 'app-protection',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1110', 'T1111'),
        Control = ('nist-800-53-r5:IA-5', 'nist-800-53-r5:AC-19'),
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
            $testResultMarkdown += "Without an Android app protection policy, nothing stands between whoever holds an unenrolled Android phone and the organization data inside Outlook, Teams and the Office apps. Create an Android app protection policy, require an app PIN and assign it."
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
        # Read the flag, not only the level: Intune keeps and returns the level whether or not the
        # flag that activates it is on, so a policy can advertise a strong value that is never applied.
        $compliant = @($policies | Where-Object {
                $_.PinRequired -and $_.SimplePinBlocked -and
                $null -ne $_.MinimumPinLength -and $_.MinimumPinLength -ge 6 -and
                $null -ne $_.MaximumPinRetries -and $_.MaximumPinRetries -gt 0 -and
                $_.MaximumPinRetries -le 5 -and
                $_.IsAssigned
            })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) Android app protection policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | PIN | Minimum length | Maximum attempts | Simple PIN | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $pinState = if ($policy.PinRequired) { 'Required' } else { 'Not required' }
            $lengthState = if ($null -eq $policy.MinimumPinLength) { 'Not configured' } else { $policy.MinimumPinLength }
            $retryState = if ($null -eq $policy.MaximumPinRetries) { 'Not configured' } else { $policy.MaximumPinRetries }
            $simpleState = if ($policy.SimplePinBlocked) { 'Blocked' } else { 'Allowed' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $pinState | $lengthState | $retryState | $simpleState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android app protection policy requires a strong app PIN."
            $gaps = @($policies | Where-Object { $_.IsAssigned -and -not ($_.PinRequired -and $_.SimplePinBlocked -and $null -ne $_.MinimumPinLength -and $_.MinimumPinLength -ge 6 -and $null -ne $_.MaximumPinRetries -and $_.MaximumPinRetries -gt 0 -and $_.MaximumPinRetries -le 5) })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
                $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
            }
        } else {
            $unassigned = @($policies | Where-Object { ($_.PinRequired -and $_.SimplePinBlocked -and $null -ne $_.MinimumPinLength -and $_.MinimumPinLength -ge 6 -and $null -ne $_.MaximumPinRetries -and $_.MaximumPinRetries -gt 0 -and $_.MaximumPinRetries -le 5) -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
            } else {
                $testResultMarkdown += "`nNo Android app protection policy requires a strong app PIN. Organization data in the managed apps is reachable by anyone holding the phone, or by guessing a short PIN without limit."
            }
        }

        $disagreeing = @($policies | Where-Object { $_.AssignmentSignalsDisagree })
        if ($disagreeing.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** on $($disagreeing.Count) policy/policies the expanded assignments and the "
            $testResultMarkdown += "isAssigned property disagree. They are counted as assigned; review their assignments in Intune."
        }

        $devicePinExemption = @($policies | Where-Object { $_.IsAssigned -and $_.DisableAppPinIfDevicePinIsSet })
        if ($devicePinExemption.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($devicePinExemption.Count) assigned policy/policies set "
            $testResultMarkdown += "**Recognize device PIN** so the app PIN is not asked for when the device has a lock. "
            $testResultMarkdown += "That is a supported trade-off, but the app PIN is then only as strong as the user's device lock."
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
