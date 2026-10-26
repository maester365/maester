function Test-MtAndroidAppProtectionDeviceAttestation {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android app protection policy requires Play Integrity device attestation.

    .DESCRIPTION
    A rooted Android phone has had the platform guarantees that the app protection model rests on
    removed. The app sandbox no longer separates the managed apps from everything else on the device,
    so an app PIN, encrypted app data and blocked data transfer all become settings enforced by code
    that another process can read and modify.

    A device compliance policy can refuse a rooted device, but only one the organization enrolled. On
    an unenrolled phone the signal reaches the organization through the Play Integrity device
    attestation condition of the app protection policy.

    Two values decide that together. The required attestation type is the gate, and the action when
    attestation fails is what happens at the gate. A policy can require attestation and only warn the
    user, which leaves the data on a device whose integrity Google has declined to vouch for.

    This test passes if at least one Android app protection policy that is assigned to a group
    requires basic integrity, or basic integrity with device certification, and blocks or wipes when
    the check fails.

    .EXAMPLE
    Test-MtAndroidAppProtectionDeviceAttestation

    Returns true if at least one assigned Android app protection policy blocks or wipes when device attestation fails.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidAppProtectionDeviceAttestation
    #>
    [MaesterTest(
        Id = 'MT.1251',
        Title = 'Ensure Android app protection policy requires Play Integrity device attestation.',
        Product = 'intune',
        Feature = 'app-protection',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1068'),
        Control = ('nist-800-53-r5:SI-7', 'nist-800-53-r5:AC-19'),
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
        $testResultMarkdown += "Without an Android app protection policy, a rooted phone opens organization data with every app protection setting it enforces running inside a sandbox that no longer separates it from the rest of the device. Create an Android app protection policy, require device attestation under **Conditional launch** and assign it."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $false
    }

    # The setting and the assignment are one condition on one policy, so they are evaluated
    # together. Two separate tests cannot express the conjunction: a policy that configures the
    # setting but is not assigned, and a policy that is assigned but does not configure it, would
    # both pass while no user is covered.
    # Read the flag, not only the level: Intune keeps and returns the level whether or not the
    # flag that activates it is on, so a policy can advertise a strong value that is never applied.
    $compliant = @($policies | Where-Object {
            $_.DeviceAttestationType -in @('basicIntegrity', 'basicIntegrityAndDeviceCertification') -and
            $_.ActionIfAttestationFailed -in @('block', 'wipe') -and
            $_.IsAssigned
        })
    $testResult = $compliant.Count -gt 0

    $testResultMarkdown = "Found $($policies.Count) Android app protection policy/policies in Intune.`n`n"
    $testResultMarkdown += "| Policy | Required attestation | Action when it fails | Assignments |`n"
    $testResultMarkdown += "| --- | --- | --- | --- |`n"
    foreach ($policy in $policies) {
        $attestationState = if ($policy.DeviceAttestationType) { $policy.DeviceAttestationType } else { 'Not configured' }
        $actionState = if ($policy.ActionIfAttestationFailed) { $policy.ActionIfAttestationFailed } else { 'Not configured' }
        $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
        $testResultMarkdown += "| $($policy.Name) | $attestationState | $actionState | $assignmentState |`n"
    }

    if ($testResult) {
        $testResultMarkdown += "`nWell done. At least one assigned Android app protection policy requires Play Integrity device attestation and acts when it fails."
        $gaps = @($policies | Where-Object { $_.IsAssigned -and -not ($_.DeviceAttestationType -in @('basicIntegrity', 'basicIntegrityAndDeviceCertification') -and $_.ActionIfAttestationFailed -in @('block', 'wipe')) })
        if ($gaps.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
            $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
        }
    } else {
        $unassigned = @($policies | Where-Object { ($_.DeviceAttestationType -in @('basicIntegrity', 'basicIntegrityAndDeviceCertification') -and $_.ActionIfAttestationFailed -in @('block', 'wipe')) -and -not $_.IsAssigned })
        if ($unassigned.Count -gt 0) {
            $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
            $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
        } else {
            $testResultMarkdown += "`nNo Android app protection policy requires Play Integrity device attestation with a blocking action. On a rooted or uncertified device the app PIN, the app data encryption and the data transfer restrictions are all enforced by code that another process on the device can read and modify."
        }
    }

    $disagreeing = @($policies | Where-Object { $_.AssignmentSignalsDisagree })
    if ($disagreeing.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Note:** on $($disagreeing.Count) policy/policies the expanded assignments and the "
        $testResultMarkdown += "isAssigned property disagree. They are counted as assigned; review their assignments in Intune."
    }

    $warnOnly = @($policies | Where-Object {
            $_.IsAssigned -and
            $_.DeviceAttestationType -in @('basicIntegrity', 'basicIntegrityAndDeviceCertification') -and
            $_.ActionIfAttestationFailed -notin @('block', 'wipe')
        })
    if ($warnOnly.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Note:** $($warnOnly.Count) assigned policy/policies require attestation but do not block "
        $testResultMarkdown += "or wipe when it fails. The check runs, the user is told, and the organization data stays on the device."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
