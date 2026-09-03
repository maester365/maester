function Test-MtMacOSDefenderRiskScore {
    <#
    .SYNOPSIS
    Ensure at least one assigned macOS compliance policy requires a Microsoft Defender machine risk score level.

    .DESCRIPTION
    Microsoft Defender for Endpoint calculates a machine risk score for every onboarded device from
    its active alerts and detections. Intune compliance policy can consume that score through
    advancedThreatProtectionRequiredSecurityLevel, so a Mac whose risk rises above an accepted
    threshold is marked non-compliant and can be blocked by Conditional Access.

    Without this setting, the Defender signal never reaches the access decision. A Mac with active
    high-severity Defender alerts stays compliant and keeps its access to corporate resources, which
    removes the automatic containment that Zero Trust assumes is present.

    The property accepts secured, low, medium and high as thresholds. The values unavailable and
    notSet mean the risk score is not evaluated at all, and neither counts as configured.

    This test passes if at least one assigned macOS compliance policy sets a real threshold. It also
    reports whether "Require the device to be at or under the machine risk score" has a matching
    Defender for Endpoint connector expectation, because a threshold on its own has no effect until
    the macOS devices are onboarded to Defender.

    .EXAMPLE
    Test-MtMacOSDefenderRiskScore

    Returns true if at least one assigned macOS compliance policy requires a Defender machine risk score level.

    .LINK
    https://maester.dev/docs/commands/Test-MtMacOSDefenderRiskScore
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose "Querying macOS compliance policies..."
        $policies = Get-MtMacOSCompliancePolicy
        if ($null -eq $policies) {
            # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
            # Report a skip rather than a false security finding.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }


        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No macOS compliance policies were found in Intune.`n`n"
            $testResultMarkdown += "Without a macOS compliance policy, the Microsoft Defender machine risk score never affects device compliance. "
            $testResultMarkdown += "Create a macOS compliance policy and set **Require the device to be at or under the machine risk score**."
            Add-MtTestResultDetail -Result $testResultMarkdown
            return $false
        }

        # unavailable and notSet both mean the risk score is not evaluated.
        $configuredLevels = @('secured', 'low', 'medium', 'high')
        # unavailable and notSet are mapped explicitly so that a genuinely unset
        # threshold reads as "Not evaluated", while an unrecognised future value
        # falls through to its raw form rather than being mislabelled as unset.
        $levelLabels = @{
            'secured'     = 'Secured (strictest)'
            'low'         = 'Low'
            'medium'      = 'Medium'
            'high'        = 'High (most permissive)'
            'unavailable' = 'Not evaluated'
            'notSet'      = 'Not evaluated'
        }

        $compliant = @($policies | Where-Object { $_.IsAssigned -and $configuredLevels -contains $_.DefenderRiskScoreLevel })
        $testResult = $compliant.Count -gt 0

        $testResultMarkdown = "Found $($policies.Count) macOS compliance policy/policies in Intune.`n`n"
        $testResultMarkdown += "| Policy | Machine risk score | Threat protection required | Assignments |`n"
        $testResultMarkdown += "| --- | --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $level = $policy.DefenderRiskScoreLevel
            $levelLabel = if ([string]::IsNullOrWhiteSpace($level)) {
                'Not evaluated'
            } elseif ($levelLabels.ContainsKey($level)) {
                $levelLabels[$level]
            } else {
                $level
            }
            $threatState = if ($policy.RequiresThreatProtection) { 'Yes' } else { 'No' }
            $assignmentState = if ($policy.IsAssigned) { $policy.AssignmentCount } else { 'None' }
            $testResultMarkdown += "| $($policy.Name) | $levelLabel | $threatState | $assignmentState |`n"
        }


        if ($testResult) {
            $testResultMarkdown += "`nWell done. At least one assigned macOS compliance policy requires a Microsoft Defender machine risk score level."
            $missingConnector = @($compliant | Where-Object { -not $_.RequiresThreatProtection })
            if ($missingConnector.Count -gt 0) {
                $testResultMarkdown += "`n`n> **Note:** $($missingConnector.Count) policy/policies set a risk score threshold but do not require "
                $testResultMarkdown += "device threat protection. Confirm your macOS devices are onboarded to Microsoft Defender for Endpoint, "
                $testResultMarkdown += "otherwise no risk score is ever reported and the threshold has no effect."
            }
        } else {
            $testResultMarkdown += "`nNo assigned macOS compliance policy requires a Microsoft Defender machine risk score level. "
            $testResultMarkdown += "A Mac with active high-severity Defender alerts stays compliant and keeps access to corporate resources."
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
