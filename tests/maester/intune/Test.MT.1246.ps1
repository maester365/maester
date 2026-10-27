function Test-MtAndroidAppProtectionEncryption {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android app protection policy encrypts organization data.

    .DESCRIPTION
    App protection encryption puts the organization's data in the managed apps under a key the Intune
    SDK controls, separately from whatever the user has done with the device. On an unenrolled Android
    phone the organization cannot verify how the device encrypts storage, and the fleet spans a decade
    of manufacturers and patch levels.

    Android exposes this as two settings that can contradict each other. One requires the app data to
    be encrypted; the other waives that requirement whenever the device reports its own encryption as
    enabled. A policy can therefore show encryption as required and encrypt nothing, because the waiver
    hands the guarantee back to the device the organization does not manage.

    This test reads both: it passes if at least one Android app protection policy that is assigned to
    a group requires app data encryption and does not disable it when device encryption is enabled.

    .EXAMPLE
    Test-MtAndroidAppProtectionEncryption

    Returns true if at least one assigned Android app protection policy encrypts organization data and does not waive it.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidAppProtectionEncryption
    #>
    [MaesterTest(
        Id = 'MT.1246',
        Title = 'Ensure Android app protection policy encrypts organization data.',
        Product = 'intune',
        Feature = 'app-protection',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1005',
        Control = ('nist-800-53-r5:SC-28(1)', 'nist-800-53-r5:AC-19'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Querying Android app protection policies..."
    try {
        $policies = Get-MtAppProtectionPolicy -Platform Android
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        throw
    }

    if ($null -eq $policies) {
        # The helper could not read the data at all: most commonly the DeviceManagementApps.Read.All
        # scope is missing from the connection, or Intune RBAC returned a 403.
        # Report a skip rather than a false security finding.
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

    if ($policies.Count -eq 0) {
        $testResultMarkdown = "No Android app protection policies were found in Intune.`n`n"
        $testResultMarkdown += "Without an Android app protection policy, organization data in the managed apps is left at rest under the device settings alone. Create an Android app protection policy, set **Encrypt org data** and assign it."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $false
    }

    # The setting and the assignment are one condition on one policy, so they are evaluated
    # together. Two separate tests cannot express the conjunction: a policy that configures the
    # setting but is not assigned, and a policy that is assigned but does not configure it, would
    # both pass while no user is covered.
    # The flag and its waiver are read together. encryptAppData alone is not the control:
    # disableAppEncryptionIfDeviceEncryptionIsEnabled switches it off on any device that reports
    # its own encryption, which is exactly what an unenrolled device cannot be trusted to report.
    $compliant = @($policies | Where-Object {
            $_.EncryptAppData -and
            -not $_.AppEncryptionDisabledByDeviceEncryption -and
            $_.IsAssigned
        })
    $testResult = $compliant.Count -gt 0

    $testResultMarkdown = "Found $($policies.Count) Android app protection policy/policies in Intune.`n`n"
    $testResultMarkdown += "| Policy | Encrypt org data | Waived when device is encrypted | Assignments |`n"
    $testResultMarkdown += "| --- | --- | --- | --- |`n"
    foreach ($policy in $policies) {
        $encryptionState = if ($policy.EncryptAppData) { 'Required' } else { 'Not required' }
        $waiverState = if ($policy.AppEncryptionDisabledByDeviceEncryption) { 'Yes' } else { 'No' }
        $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
        $testResultMarkdown += "| $($policy.Name) | $encryptionState | $waiverState | $assignmentState |`n"
    }

    if ($testResult) {
        $testResultMarkdown += "`nWell done. At least one assigned Android app protection policy encrypts organization data without waiving it."
        $gaps = @($policies | Where-Object { $_.IsAssigned -and -not ($_.EncryptAppData -and -not $_.AppEncryptionDisabledByDeviceEncryption) })
        if ($gaps.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
            $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
        }
    } else {
        $unassigned = @($policies | Where-Object { ($_.EncryptAppData -and -not $_.AppEncryptionDisabledByDeviceEncryption) -and -not $_.IsAssigned })
        if ($unassigned.Count -gt 0) {
            $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
            $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
        } else {
            $testResultMarkdown += "`nNo Android app protection policy encrypts organization data under the policy's own key. Either encryption is not required, or it is waived on any device that reports its own encryption as enabled, which an unenrolled device cannot be trusted to report."
        }
    }

    $disagreeing = @($policies | Where-Object { $_.AssignmentSignalsDisagree })
    if ($disagreeing.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Note:** on $($disagreeing.Count) policy/policies the expanded assignments and the "
        $testResultMarkdown += "isAssigned property disagree. They are counted as assigned; review their assignments in Intune."
    }

    $waived = @($policies | Where-Object { $_.IsAssigned -and $_.EncryptAppData -and $_.AppEncryptionDisabledByDeviceEncryption })
    if ($waived.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Note:** $($waived.Count) assigned policy/policies require encryption and also set "
        $testResultMarkdown += "**Encrypt org data on enrolled devices** to disable it when the device is encrypted. "
        $testResultMarkdown += "Those policies read as protective in the portal and encrypt nothing on a device that reports device encryption."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
