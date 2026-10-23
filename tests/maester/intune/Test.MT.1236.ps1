function Test-MtAndroidUsbDebugging {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android compliance policy blocks USB debugging.

    .DESCRIPTION
    USB debugging exposes the Android Debug Bridge over the device's cable. On a device where it is
    enabled, a host the user has authorised can install and launch applications, read the data of any
    app built as debuggable, and drive the user interface. It is a developer feature that stays on long
    after whatever needed it, and the user has no reason to notice.

    Intune compliance policy can evaluate it through securityDisableUsbDebugging, so a device with USB
    debugging enabled is marked non-compliant and can then be blocked by Conditional Access.

    This is hardening rather than a primary control: using it takes physical access to the device, an
    unlocked screen and the user accepting the host key. What it removes is the quiet path by which a
    phone left on a desk, or handed to a repair shop, gives up its app data.

    Only #microsoft.graph.androidCompliancePolicy, the device administrator policy type, is evaluated.
    Android Enterprise policies are reported but not evaluated, and a tenant that has only those is
    reported as not applicable rather than as a failure. See the scope limitation in the guide.

    .EXAMPLE
    Test-MtAndroidUsbDebugging

    Returns true if at least one assigned Android compliance policy blocks USB debugging.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidUsbDebugging
    #>
    [MaesterTest(
        Id = 'MT.1236',
        Title = 'Ensure Android compliance policy blocks USB debugging.',
        Product = 'intune',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1005', 'T1052.001'),
        Control = ('nist-800-53-r5:SC-41', 'nist-800-53-r5:CM-7'),
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
            $testResultMarkdown += "Without an Android compliance policy, a device with USB debugging enabled is still reported as compliant. "
            $testResultMarkdown += "Create an Android compliance policy and set **USB debugging** to **Block**."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        $evaluated = @($policies | Where-Object { $_.SettingsEvaluated })
        $enterprise = @($policies | Where-Object { -not $_.SettingsEvaluated })
        if ($evaluated.Count -eq 0) {
            # The tenant manages Android through Android Enterprise only. This setting is read from the
            # device administrator policy type, so there is nothing to evaluate here.
            Add-MtTestResultDetail -SkippedBecause NotApplicable
            return $null
        }

        $compliant = @($evaluated | Where-Object { $_.UsbDebuggingDisabled -and $_.IsAssigned })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($evaluated.Count) Android device administrator compliance policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | USB debugging | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($policy in $evaluated) {
            $usbState = if ($policy.UsbDebuggingDisabled) { 'Blocked' } else { 'Not configured' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $usbState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android compliance policy blocks USB debugging."
            $gaps = @($evaluated | Where-Object { -not $_.UsbDebuggingDisabled -and $_.IsAssigned })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not block USB debugging. "
                $testResultMarkdown += "Devices scoped only to those policies are not evaluated for it."
            }
        } else {
            $unassigned = @($evaluated | Where-Object { $_.UsbDebuggingDisabled -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies block USB debugging but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never evaluated. Assign the policy to your Android device or user groups."
            } else {
                $testResultMarkdown += "`nNo Android compliance policy blocks USB debugging. "
                $testResultMarkdown += "A device left with the developer option enabled keeps its app data reachable over the cable and stays compliant."
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
