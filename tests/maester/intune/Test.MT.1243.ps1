function Test-MtIosAppProtectionDeviceThreatLevel {
    <#
    .SYNOPSIS
    Ensure at least one assigned iOS app protection policy acts on the device threat level.

    .DESCRIPTION
    Device compliance policies can refuse a jailbroken iPhone, but they only evaluate a device the
    organization enrolled. On an unenrolled phone the equivalent signal reaches the organization
    through the app protection policy: a mobile threat defense partner such as Microsoft Defender
    reports a threat level for the device, and the policy decides what the managed app does about it.

    Two values decide that together. The maximum allowed device threat level is the gate, and the
    remediation action is what happens when the gate is crossed. A policy can name a strict level and
    still only warn the user, which leaves the data available on a device the organization has been
    told is compromised.

    A level of high accepts every threat the partner reports, so it is treated here as configured but
    not protective.

    This test passes if at least one iOS app protection policy that is assigned to a group sets the
    maximum allowed device threat level to secured, low or medium and blocks or wipes when it is
    exceeded.

    .EXAMPLE
    Test-MtIosAppProtectionDeviceThreatLevel

    Returns true if at least one assigned iOS app protection policy blocks or wipes on a device threat signal.

    .LINK
    https://maester.dev/docs/commands/Test-MtIosAppProtectionDeviceThreatLevel
    #>
    [MaesterTest(
        Id = 'MT.1243',
        Title = 'Ensure iOS app protection policy acts on the device threat level.',
        Product = 'intune',
        Feature = 'app-protection',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1068', 'T1078.004'),
        Control = ('nist-800-53-r5:SI-4', 'nist-800-53-r5:AC-19'),
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
        $testResultMarkdown += "Without an iOS app protection policy, no mobile threat defense signal can reach a decision about organization data on an unenrolled iPhone. Create an iOS app protection policy, set **Max allowed device threat level** under **Conditional launch** and assign it."
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
            $_.MaximumDeviceThreatLevel -in @('secured', 'low', 'medium') -and
            $_.ThreatRemediationAction -in @('block', 'wipe') -and
            $_.IsAssigned
        })
    $testResult = $compliant.Count -gt 0

    $testResultMarkdown = "Found $($policies.Count) iOS app protection policy/policies in Intune.`n`n"
    $testResultMarkdown += "| Policy | Maximum device threat level | Action | Assignments |`n"
    $testResultMarkdown += "| --- | --- | --- | --- |`n"
    foreach ($policy in $policies) {
        $threatState = if ($policy.MaximumDeviceThreatLevel) { $policy.MaximumDeviceThreatLevel } else { 'Not configured' }
        $actionState = if ($policy.ThreatRemediationAction) { $policy.ThreatRemediationAction } else { 'Not configured' }
        $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
        $testResultMarkdown += "| $($policy.Name) | $threatState | $actionState | $assignmentState |`n"
    }

    if ($testResult) {
        $testResultMarkdown += "`nWell done. At least one assigned iOS app protection policy blocks or wipes organization data on a device threat signal."
        $gaps = @($policies | Where-Object { $_.IsAssigned -and -not ($_.MaximumDeviceThreatLevel -in @('secured', 'low', 'medium') -and $_.ThreatRemediationAction -in @('block', 'wipe')) })
        if ($gaps.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not meet this requirement. "
            $testResultMarkdown += "Users whose apps are covered only by those policies are not protected by it."
        }
    } else {
        $unassigned = @($policies | Where-Object { ($_.MaximumDeviceThreatLevel -in @('secured', 'low', 'medium') -and $_.ThreatRemediationAction -in @('block', 'wipe')) -and -not $_.IsAssigned })
        if ($unassigned.Count -gt 0) {
            $testResultMarkdown += "`n$($unassigned.Count) policy/policies meet this requirement but are **not assigned** to any group, "
            $testResultMarkdown += "so they are never applied to a user. Assign the policy to your user groups."
        } else {
            $testResultMarkdown += "`nNo iOS app protection policy acts on the device threat level. On an unenrolled iPhone this is the only path by which a jailbreak or a malicious app detected by mobile threat defense can reach a decision about the organization data, and nothing is listening."
        }
    }

    $disagreeing = @($policies | Where-Object { $_.AssignmentSignalsDisagree })
    if ($disagreeing.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Note:** on $($disagreeing.Count) policy/policies the expanded assignments and the "
        $testResultMarkdown += "isAssigned property disagree. They are counted as assigned; review their assignments in Intune."
    }

    $permissive = @($policies | Where-Object { $_.IsAssigned -and $_.MaximumDeviceThreatLevel -eq 'high' })
    if ($permissive.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Note:** $($permissive.Count) assigned policy/policies set the maximum allowed device "
        $testResultMarkdown += "threat level to **high**, which accepts every threat level the partner reports. The condition is "
        $testResultMarkdown += "configured but admits a device reported as high risk."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
