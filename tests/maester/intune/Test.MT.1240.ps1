function Test-MtIosAppProtectionEncryption {
    <#
    .SYNOPSIS
    Ensure at least one assigned iOS app protection policy encrypts organization data.

    .DESCRIPTION
    App protection encryption puts the organization's data in the managed apps under a key the Intune
    SDK controls, separately from whatever the user has done with the device. On an unenrolled phone
    the organization cannot require a device passcode, and iOS data protection is only as strong as
    the passcode behind it; a device with no passcode gives little protection to files at rest.

    The setting is not a switch but a choice of when the data is encrypted. Leaving it on
    useDeviceSettings defers the question to the device, which is precisely the thing an unenrolled
    phone does not guarantee.

    This test passes if at least one iOS app protection policy that is assigned to a group encrypts
    organization data when the device is locked, when the device is locked except for open files, or
    after a device restart.

    .EXAMPLE
    Test-MtIosAppProtectionEncryption

    Returns true if at least one assigned iOS app protection policy encrypts organization data.

    .LINK
    https://maester.dev/docs/commands/Test-MtIosAppProtectionEncryption
    #>
    [MaesterTest(
        Id = 'MT.1240',
        Title = 'Ensure iOS app protection policy encrypts organization data.',
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

    Write-Verbose "Querying iOS app protection policies..."
    try {
        $policies = Get-MtAppProtectionPolicy -Platform iOS
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
        $testResultMarkdown = "No iOS app protection policies were found in Intune.`n`n"
        $testResultMarkdown += "Without an iOS app protection policy, organization data in the managed apps is left at rest under the device settings alone. Create an iOS app protection policy, set **Encrypt org data** and assign it."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $false
    }

    # The setting and the assignment are one condition on one policy, so they are evaluated
    # together. Two separate tests cannot express the conjunction: a policy that configures the
    # setting but is not assigned, and a policy that is assigned but does not configure it, would
    # both pass while no user is covered.
    $compliant = @($policies | Where-Object {
            $_.AppDataEncryptionType -in @('whenDeviceLocked', 'whenDeviceLockedExceptOpenFiles', 'afterDeviceRestart') -and
            $_.IsAssigned
        })
    $testResult = $compliant.Count -gt 0

    $testResultMarkdown = "Found $($policies.Count) iOS app protection policy/policies in Intune.`n`n"
    $testResultMarkdown += "| Policy | Encrypt org data | Assignments |`n"
    $testResultMarkdown += "| --- | --- | --- |`n"
    foreach ($policy in $policies) {
        $encryptionState = if ($policy.AppDataEncryptionType) { $policy.AppDataEncryptionType } else { 'Not configured' }
        $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
        $testResultMarkdown += "| $($policy.Name) | $encryptionState | $assignmentState |`n"
    }

    if ($testResult) {
        $testResultMarkdown += "`nWell done. At least one assigned iOS app protection policy encrypts organization data."
        $gaps = @($policies | Where-Object { $_.IsAssigned -and -not ($_.AppDataEncryptionType -in @('whenDeviceLocked', 'whenDeviceLockedExceptOpenFiles', 'afterDeviceRestart')) })
        if ($gaps.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
            $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
        }
    } else {
        $unassigned = @($policies | Where-Object { ($_.AppDataEncryptionType -in @('whenDeviceLocked', 'whenDeviceLockedExceptOpenFiles', 'afterDeviceRestart')) -and -not $_.IsAssigned })
        if ($unassigned.Count -gt 0) {
            $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
            $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
        } else {
            $testResultMarkdown += "`nNo iOS app protection policy encrypts organization data independently of the device settings. On a phone with a weak passcode or none at all, the organization data in the managed apps is left at rest with whatever protection the device happens to provide."
        }
    }

    $disagreeing = @($policies | Where-Object { $_.AssignmentSignalsDisagree })
    if ($disagreeing.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Note:** on $($disagreeing.Count) policy/policies the expanded assignments and the "
        $testResultMarkdown += "isAssigned property disagree. They are counted as assigned; review their assignments in Intune."
    }


    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
