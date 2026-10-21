function Test-MtAndroidRootedDevices {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android compliance policy blocks rooted devices.

    .DESCRIPTION
    A rooted Android device has had the boundary the platform is trusted for removed. The application
    sandbox no longer separates apps, so the credentials and refresh tokens the Authenticator, Outlook
    and Teams keep on the device can be read by anything with root, and verified boot no longer
    guarantees that the running system is the one Google signed.

    Intune cannot prevent a device from being rooted. What it can do is evaluate the root signal as a
    compliance condition, so the device is marked non-compliant and can then be blocked by Conditional
    Access. Without that rule, Intune reports a rooted device as healthy and it keeps its access to
    corporate resources with its platform guarantees gone.

    This test passes if at least one Android compliance policy that is assigned to a group sets
    "Rooted devices" to Block. Policies with no assignment are reported but do not count towards a
    pass, because an unassigned compliance policy is never evaluated.

    Only #microsoft.graph.androidCompliancePolicy, the device administrator policy type, is evaluated.
    Android Enterprise policies are reported but not evaluated, and a tenant that has only those is
    reported as not applicable rather than as a failure. See the scope limitation in the guide.

    .EXAMPLE
    Test-MtAndroidRootedDevices

    Returns true if at least one assigned Android compliance policy blocks rooted devices.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidRootedDevices
    #>
    [MaesterTest(
        Id = 'MT.TBD-05',
        Title = 'Ensure Android compliance policy blocks rooted devices.',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1068', 'T1553.006'),
        Control = ('nist-800-53-r5:SI-7', 'nist-800-53-r5:AC-19'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose "Querying Android compliance policies..."
        $policies = Get-MtMobileCompliancePolicy -Platform Android
        if ($null -eq $policies) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No Android compliance policies were found in Intune.`n`n"
            $testResultMarkdown += "Without an Android compliance policy, a rooted device is still reported as compliant. "
            $testResultMarkdown += "Create an Android compliance policy and set **Rooted devices** to **Block**."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        $evaluated = @($policies | Where-Object { $_.SettingsEvaluated })
        $enterprise = @($policies | Where-Object { -not $_.SettingsEvaluated })
        if ($evaluated.Count -eq 0) {
            # The tenant manages Android through Android Enterprise only. This setting is read from the
            # device administrator policy type, so there is nothing to evaluate and its absence is not
            # a finding.
            Add-MtTestResultDetail -SkippedBecause NotApplicable
            return $null
        }

        $compliant = @($evaluated | Where-Object { $_.BlocksRootedDevices -and $_.IsAssigned })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($evaluated.Count) Android device administrator compliance policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Rooted devices | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($policy in $evaluated) {
            $rootState = if ($policy.BlocksRootedDevices) { 'Blocked' } else { 'Not configured' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $rootState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android compliance policy blocks rooted devices."
            $gaps = @($evaluated | Where-Object { -not $_.BlocksRootedDevices -and $_.IsAssigned })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not block rooted devices. "
                $testResultMarkdown += "Devices scoped only to those policies are not evaluated for root detection."
            }
        } else {
            $unassigned = @($evaluated | Where-Object { $_.BlocksRootedDevices -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies block rooted devices but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never evaluated. Assign the policy to your Android device or user groups."
            } else {
                $testResultMarkdown += "`nNo Android compliance policy blocks rooted devices. "
                $testResultMarkdown += "A rooted device is reported as compliant and keeps access to corporate resources."
            }
        }

        if ($enterprise.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Scope:** $($enterprise.Count) Android Enterprise compliance policy/policies "
            $testResultMarkdown += "(work profile or device owner) are configured in this tenant and are **not evaluated** by this test."
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
