function Get-MtAzureDefenderForCloudRecommendationInstance {
    <#
    .SYNOPSIS
    Returns one MT.1271 instance per Microsoft Defender for Cloud recommendation.

    .DESCRIPTION
    Instance source of the MT.1271 family. The suffix is the recommendation's assessment key
    (MT.1271.<assessmentKey>) and the title names the recommendation, the way MT.1024 does for Entra
    recommendations. One instance per recommendation, never one per resource: a large estate produces
    thousands of assessment rows and only hundreds of recommendations.

    When Defender for Cloud returns no assessment at all the source emits nothing and the engine skips
    the family with NoInstances. A subscription with no assessment has no recommendation to comply
    with, and must never be reported as having none unhealthy.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $recommendations = Get-MtDefenderForCloudRecommendation

    foreach ($recommendation in $recommendations) {
        # A recommendation evaluated against no resource has no outcome to judge.
        if ($recommendation.TotalCount -le 0) { continue }

        $name = if ([string]::IsNullOrWhiteSpace($recommendation.DisplayName)) {
            $recommendation.AssessmentKey
        } else {
            $recommendation.DisplayName
        }

        # Severity follows the source, as #2510 asks. It goes on the instance because that is where the
        # engine reads a family's per-instance severity (Invoke-MtNativePlan resolves config, then the
        # instance, then the attribute); -Severity on Add-MtTestResultDetail is never reached once the
        # attribute declares one.
        # The Defender CSPM risk level is preferred when present, otherwise the recommendation's own
        # metadata severity.
        $source = if (-not [string]::IsNullOrWhiteSpace($recommendation.RiskLevel)) { $recommendation.RiskLevel } else { $recommendation.Severity }
        $severity = switch -Regex ($source) {
            '^(Critical|High)$' { 'High'; break }
            '^Medium$'          { 'Medium'; break }
            '^Low$'             { 'Low'; break }
            default             { 'Medium' }
        }

        [pscustomobject]@{
            Id       = $recommendation.AssessmentKey
            Title    = "No resource should be left unhealthy for the Defender for Cloud recommendation '$name'."
            Severity = $severity
            Data     = $recommendation
        }
    }
}

function Test-MtAzureDefenderForCloudRecommendation {
    <#
    .SYNOPSIS
    Ensure no resource is left unhealthy for a Microsoft Defender for Cloud recommendation.

    .DESCRIPTION
    Defender for Cloud assesses the resources of every subscription it covers against a catalogue of
    recommendations and reports, per recommendation, which resources are healthy. An assessor normally
    reads that one recommendation at a time in the Azure portal. This check brings it into a Maester
    run.

    It runs once per recommendation, following the InstanceSource pattern MT.1024 introduced. A
    recommendation passes when no resource is unhealthy and fails when any is, with the resource
    counts, a sample of the unhealthy resource names and the portal link to the full list.

    Severity follows the source, as #2510 asks. Defender CSPM adds a risk level per recommendation,
    and that is preferred when present; otherwise the recommendation's own metadata severity is used.

    A recommendation whose resources are all exempt is skipped with the exemption cause, so a decision
    already recorded in the Azure portal is respected rather than reported again. A recommendation that
    applies to nothing is skipped as not applicable. Neither is reported as a pass.

    .OUTPUTS
    [bool] - True when no resource is unhealthy, false when any is, null when skipped.

    .EXAMPLE
    Test-MtAzureDefenderForCloudRecommendation

    Returns one result per Defender for Cloud recommendation.

    .LINK
    https://maester.dev/docs/commands/Test-MtAzureDefenderForCloudRecommendation
    #>
    [MaesterTest(
        Id = 'MT.1271',
        Title = 'Resources should be healthy for the Microsoft Defender for Cloud recommendations.',
        Product = 'azure',
        RelatedProduct = 'defender',
        Feature = 'subscriptions',
        Area = 'infrastructure',
        ResourceType = 'AzureResource',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Lifecycle = 'Preview',
        Service = 'Azure',
        InstanceSource = 'Get-MtAzureDefenderForCloudRecommendationInstance',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The recommendation to check, supplied by the engine.
        $Instance
    )

    $recommendation = $Instance.Data
    $unhealthy = [int]$recommendation.UnhealthyCount
    $healthy = [int]$recommendation.HealthyCount
    $notApplicable = [int]$recommendation.NotApplicableCount
    $exempt = [int]$recommendation.ExemptCount
    $total = [int]$recommendation.TotalCount

    if ($exempt -gt 0 -and $exempt -eq $total) {
        # Every resource is exempt, which is a decision already recorded in the Azure portal. Respect
        # it instead of reporting the recommendation again.
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Every resource for this recommendation is exempt in Defender for Cloud ($exempt of $total)."
        return $null
    }

    if ($unhealthy -eq 0 -and $healthy -eq 0) {
        # Nothing was evaluated either way. No unhealthy resource over no evaluated resource is not a
        # pass.
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $testResult = $unhealthy -eq 0

    $testResultMarkdown = "Defender for Cloud assessed **$total** resource(s) for this recommendation. "
    if ($testResult) {
        $testResultMarkdown += "None is unhealthy.`n`n"
    } else {
        $testResultMarkdown += "**$unhealthy** of them are unhealthy.`n`n"
    }

    $testResultMarkdown += "| Property | Value |`n| --- | --- |`n"
    $testResultMarkdown += "| Assessment key | ``$($recommendation.AssessmentKey)`` |`n"
    $testResultMarkdown += "| Unhealthy | $unhealthy |`n"
    $testResultMarkdown += "| Healthy | $healthy |`n"
    $testResultMarkdown += "| Not applicable | $notApplicable |`n"
    if ($exempt -gt 0) { $testResultMarkdown += "| Exempt | $exempt |`n" }
    if (-not [string]::IsNullOrWhiteSpace($recommendation.Severity)) { $testResultMarkdown += "| Severity in Defender for Cloud | $($recommendation.Severity) |`n" }
    if (-not [string]::IsNullOrWhiteSpace($recommendation.RiskLevel)) { $testResultMarkdown += "| Risk level (Defender CSPM) | $($recommendation.RiskLevel) |`n" }

    if (-not $testResult) {
        $resources = @($recommendation.UnhealthyResourceList | Where-Object { $_ })
        if ($resources.Count -gt 0) {
            # "up to ten shown" does not tell the reader whether ten is all of them. The total does.
            $resourceLabel = if ([int]$recommendation.UnhealthyResourceTotal -gt $resources.Count) { "$($resources.Count) of $([int]$recommendation.UnhealthyResourceTotal)" } else { 'all' }
            # Resource names come from the tenant, so they are escaped before reaching Markdown.
            $safeResources = @($resources | ForEach-Object { Get-MtSafeMarkdown $_ })
            $testResultMarkdown += "`nUnhealthy resources ($resourceLabel): $($safeResources -join ', ')`n"
        }
        if (-not [string]::IsNullOrWhiteSpace($recommendation.PortalUri)) {
            $testResultMarkdown += "`n[Open this recommendation in the Azure portal]($($recommendation.PortalUri))`n"
        }
        $testResultMarkdown += "`nRemediate the resources listed, or exempt the recommendation in Defender for Cloud so the decision is recorded there."
    } else {
        $testResultMarkdown += "`nWell done. Every resource Defender for Cloud evaluated for this recommendation is healthy."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
