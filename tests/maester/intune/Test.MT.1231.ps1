function Test-MtIosDefenderRiskScore {
    <#
    .SYNOPSIS
    Ensure at least one assigned iOS compliance policy requires a Microsoft Defender machine risk score level.

    .DESCRIPTION
    Microsoft Defender for Endpoint on iOS calculates a machine risk score for every onboarded device
    from what it detects on it: malicious or phishing web traffic, a jailbreak, a known bad app, an
    unsafe network. Intune compliance policy consumes that verdict through
    advancedThreatProtectionRequiredSecurityLevel, so an iPhone whose risk rises above an accepted
    threshold is marked non-compliant and can be blocked by Conditional Access.

    Only the Defender for Endpoint threshold is read. A tenant that uses a third party mobile threat
    defense connector configures a different property, which this check does not read, so read a
    failure here together with the connectors MT.1098 reports on.

    Without this setting the detection never reaches the access decision. A phone with an active
    high severity detection stays compliant and keeps its access to corporate resources, which removes
    the automatic containment that Zero Trust assumes is present.

    The property accepts secured, low, medium and high. A threshold of high admits every risk score
    Defender reports, so it is treated here as configured but not protective, the same way MT.1243 and
    MT.1249 treat the app protection threat level. The values unavailable and notSet mean the risk
    level is not evaluated at all, and neither counts as configured.

    This test passes if at least one assigned iOS compliance policy sets a real threshold. It also
    reports whether the policy requires device threat protection, because a threshold on its own has no
    effect until the devices are onboarded to a threat defense service and its connector is enabled.

    .EXAMPLE
    Test-MtIosDefenderRiskScore

    Returns true if at least one assigned iOS compliance policy requires a Defender machine risk score level.

    .LINK
    https://maester.dev/docs/commands/Test-MtIosDefenderRiskScore
    #>
    [MaesterTest(
        Id = 'MT.1231',
        Title = 'Ensure iOS compliance policy requires a Defender machine risk score level.',
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

    Write-Verbose "Querying iOS compliance policies..."
    try {
        $policies = Get-MtMobileCompliancePolicy -Platform iOS
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }

        throw
    }

    if ($null -eq $policies) {
        # The helper could not read the data at all, most commonly a 403 from Intune RBAC.
        # Report a skip rather than a false security finding.
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

    if ($policies.Count -eq 0) {
        $testResultMarkdown = "No iOS compliance policies were found in Intune.`n`n"
        $testResultMarkdown += "Without an iOS compliance policy, a Defender detection never affects device compliance. "
        $testResultMarkdown += "Create an iOS/iPadOS compliance policy and set **Require the device to be at or under the machine risk score**."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $false
    }

    # A protective threshold is one that can mark a device non-compliant. high accepts every score
    # Defender reports, so it is reported below rather than counted as a pass; unavailable and notSet
    # both mean the risk level is not evaluated at all.
    $configuredLevels = @('secured', 'low', 'medium')
    # unavailable and notSet are mapped explicitly so that a genuinely unset threshold reads as
    # "Not evaluated", while an unrecognised future value falls through to its raw form rather than
    # being mislabelled as unset.
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

    $testResultMarkdown = "Found $($policies.Count) iOS compliance policy/policies in Intune.`n`n"
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
        $testResultMarkdown += "`nWell done. At least one assigned iOS compliance policy requires a Microsoft Defender machine risk score level."
        $missingConnector = @($compliant | Where-Object { -not $_.RequiresThreatProtection })
        if ($missingConnector.Count -gt 0) {
            $testResultMarkdown += "`n`n> **Note:** $($missingConnector.Count) policy/policies set a risk level threshold but do not require "
            $testResultMarkdown += "device threat protection. Confirm your iOS devices are onboarded to Microsoft Defender for Endpoint, "
            $testResultMarkdown += "otherwise no risk level is ever reported and the threshold has no effect."
        }
    } else {
        $unassigned = @($policies | Where-Object { -not $_.IsAssigned -and $configuredLevels -contains $_.DefenderRiskScoreLevel })
        if ($unassigned.Count -gt 0) {
            $testResultMarkdown += "`n$($unassigned.Count) policy/policies require a risk level but are **not assigned** to any group, "
            $testResultMarkdown += "so they are never evaluated. Assign the policy to your iOS device or user groups."
        } else {
            $testResultMarkdown += "`nNo assigned iOS compliance policy requires a protective Microsoft Defender machine risk score level. "
            $testResultMarkdown += "A phone with an active high severity detection stays compliant and keeps access to corporate resources."
        }
    }

    $permissive = @($policies | Where-Object { $_.IsAssigned -and $_.DefenderRiskScoreLevel -eq 'high' })
    if ($permissive.Count -gt 0) {
        $testResultMarkdown += "`n`n> **Note:** $($permissive.Count) assigned policy/policies set the machine risk score "
        $testResultMarkdown += "threshold to **high**, which admits every score Defender reports. The threshold is configured "
        $testResultMarkdown += "but no detection makes the device non-compliant."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
