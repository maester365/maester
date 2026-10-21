function Test-MtAndroidThreatProtection {
    <#
    .SYNOPSIS
    Ensure at least one assigned Android compliance policy requires device threat protection.

    .DESCRIPTION
    Microsoft Defender for Endpoint on Android, and the other mobile threat defense connectors Intune
    supports, report what they find on a device: a malicious app, phishing web traffic, root, an unsafe
    network. Intune compliance policy consumes that through deviceThreatProtectionEnabled, so a phone
    the service considers at risk is marked non-compliant and can be blocked by Conditional Access.

    Without this setting the detection never reaches the access decision. A phone with an active
    detection stays compliant and keeps its access to corporate resources, which removes the automatic
    containment that Zero Trust assumes is present.

    The setting has no effect until the devices are onboarded to a threat defense service and its
    connector is enabled and set to evaluate Android, so a failure here is read together with MT.1098,
    which checks the health of the connectors themselves.

    Only #microsoft.graph.androidCompliancePolicy, the device administrator policy type, is evaluated.
    Android Enterprise policies are reported but not evaluated, and a tenant that has only those is
    reported as not applicable rather than as a failure. See the scope limitation in the guide.

    .EXAMPLE
    Test-MtAndroidThreatProtection

    Returns true if at least one assigned Android compliance policy requires device threat protection.

    .LINK
    https://maester.dev/docs/commands/Test-MtAndroidThreatProtection
    #>
    [MaesterTest(
        Id = 'MT.TBD-08',
        Title = 'Ensure Android compliance policy requires device threat protection.',
        Product = 'intune',
        RelatedProduct = 'defender',
        Feature = 'device-compliance',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('nist-800-53-r5:SI-4', 'nist-800-53-r5:AC-19'),
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
            $testResultMarkdown += "Without an Android compliance policy, a mobile threat defense detection never affects device compliance. "
            $testResultMarkdown += "Create an Android compliance policy and set **Require the device to be at or under the device threat level**."
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

        $compliant = @($evaluated | Where-Object { $_.RequiresThreatProtection -and $_.IsAssigned })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($evaluated.Count) Android device administrator compliance policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Threat protection required | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        foreach ($policy in $evaluated) {
            $threatState = if ($policy.RequiresThreatProtection) { 'Yes' } else { 'Not configured' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $threatState | $assignmentState |`n"
        }

        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned Android compliance policy requires device threat protection."
            $testResultMarkdown += "`n`n> **Note:** this setting only has an effect while a mobile threat defense connector is enabled and set "
            $testResultMarkdown += "to evaluate Android devices, and the devices are onboarded to it. MT.1098 reports the health of the connectors."
            $gaps = @($evaluated | Where-Object { -not $_.RequiresThreatProtection -and $_.IsAssigned })
            if ($gaps.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($gaps.Count) assigned policy/policies do not require device threat protection. "
                $testResultMarkdown += "Devices scoped only to those policies keep access whatever the threat defense service reports."
            }
        } else {
            $unassigned = @($evaluated | Where-Object { $_.RequiresThreatProtection -and -not $_.IsAssigned })
            if ($unassigned.Count -gt 0) {
                $testResultMarkdown += "`n$($unassigned.Count) policy/policies require device threat protection but are **not assigned** to any group, "
                $testResultMarkdown += "so they are never evaluated. Assign the policy to your Android device or user groups."
            } else {
                $testResultMarkdown += "`nNo assigned Android compliance policy requires device threat protection. "
                $testResultMarkdown += "A phone with an active detection stays compliant and keeps access to corporate resources."
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
