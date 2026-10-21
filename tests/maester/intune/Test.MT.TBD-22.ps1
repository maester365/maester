function Test-MtIosAppProtectionDataTransfer {
    <#
    .SYNOPSIS
    Ensure at least one assigned iOS app protection policy keeps organization data inside managed apps.

    .DESCRIPTION
    This is the control a device compliance policy cannot provide. A tenant can require a compliant,
    passcode-protected, up-to-date iPhone and still let a user forward an attachment from Outlook into
    a personal cloud drive, paste a customer list into a note-taking app, or let iCloud back the whole
    mailbox up to a personal Apple account.

    Four settings decide whether organization data can leave the managed boundary: where the app may
    send data, what the clipboard may carry out, whether "Save as" to a personal location is allowed,
    and whether the app's data is included in the device backup. Any one of them left open is a route
    out, so all four are read from the same policy.

    This test passes if at least one iOS app protection policy that is assigned to a group restricts
    data transfer and clipboard sharing to managed apps, blocks save-as to personal locations and
    blocks the app data backup.

    .EXAMPLE
    Test-MtIosAppProtectionDataTransfer

    Returns true if at least one assigned iOS app protection policy blocks organization data from leaving managed apps.

    .LINK
    https://maester.dev/docs/commands/Test-MtIosAppProtectionDataTransfer
    #>
    [MaesterTest(
        Id = 'MT.TBD-22',
        Title = 'Ensure iOS app protection policy keeps organization data inside managed apps.',
        Product = 'intune',
        Feature = 'app-protection',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1530', 'T1115'),
        Control = ('nist-800-53-r5:AC-4', 'nist-800-53-r5:AC-19'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose "Querying iOS app protection policies..."
        $policies = Get-MtAppProtectionPolicy -Platform iOS
        if ($null -eq $policies) {
            # The helper could not read the data at all: most commonly the DeviceManagementApps.Read.All
            # scope is missing from the connection, or Intune RBAC returned a 403.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No iOS app protection policies were found in Intune.`n`n"
            $testResultMarkdown += "Without an iOS app protection policy, organization data in Outlook, Teams and the Office apps can be copied or saved into any personal app on the device. Create an iOS app protection policy, restrict data transfer to managed apps and assign it."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # The setting and the assignment are one condition on one policy, so they are evaluated
        # together. Two separate tests cannot express the conjunction: a policy that configures the
        # setting but is not assigned, and a policy that is assigned but does not configure it, would
        # both pass while no user is covered.
        $compliant = @($policies | Where-Object {
                $_.OutboundDataTransfer -in @('managedApps', 'none') -and
                $_.ClipboardSharingLevel -in @('managedApps', 'managedAppsWithPasteIn', 'blocked') -and
                $_.SaveAsBlocked -and $_.DataBackupBlocked -and
                $_.IsAssigned
            })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) iOS app protection policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Send data to | Clipboard | Save as | App data backup | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $outboundState = if ($policy.OutboundDataTransfer) { $policy.OutboundDataTransfer } else { 'Not configured' }
            $clipboardState = if ($policy.ClipboardSharingLevel) { $policy.ClipboardSharingLevel } else { 'Not configured' }
            $saveAsState = if ($policy.SaveAsBlocked) { 'Blocked' } else { 'Allowed' }
            $backupState = if ($policy.DataBackupBlocked) { 'Blocked' } else { 'Allowed' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $outboundState | $clipboardState | $saveAsState | $backupState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned iOS app protection policy keeps organization data inside managed apps."
            $gaps = @($policies | Where-Object { $_.IsAssigned -and -not ($_.OutboundDataTransfer -in @('managedApps', 'none') -and $_.ClipboardSharingLevel -in @('managedApps', 'managedAppsWithPasteIn', 'blocked') -and $_.SaveAsBlocked -and $_.DataBackupBlocked) })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
                $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
            }
        } else {
            $unassigned = @($policies | Where-Object { ($_.OutboundDataTransfer -in @('managedApps', 'none') -and $_.ClipboardSharingLevel -in @('managedApps', 'managedAppsWithPasteIn', 'blocked') -and $_.SaveAsBlocked -and $_.DataBackupBlocked) -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
            } else {
                $testResultMarkdown += "`nNo iOS app protection policy keeps organization data inside managed apps. Mail, files and chat content can be copied, saved or backed up into personal apps and personal cloud accounts, and the device can be fully compliant while that happens."
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
