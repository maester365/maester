function Get-MtAzureDefenderForCloudAttackPathInstance {
    <#
    .SYNOPSIS
    Returns one MT.1258 instance per Microsoft Defender for Cloud attack path.

    .DESCRIPTION
    Instance source of the MT.1258 family. One instance per attack path, titled with the path itself,
    which Defender for Cloud phrases as a sentence naming the entry point and the target.

    When Defender CSPM is not enabled on any readable subscription the source reports the family as not
    licensed, because no attack path was ever computed and an empty result there says nothing about the
    estate. When the plan is on and no path exists the source emits nothing and the engine skips the
    family with NoInstances.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $attackPaths = Get-MtDefenderForCloudAttackPath

    if (-not $attackPaths.CspmEnabled) {
        # Attack paths are computed by Defender CSPM. Without the plan there is nothing to read, and an
        # empty result must not be read as an estate with no attack path.
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Defender CSPM is not enabled on any readable subscription, so Defender for Cloud computes no attack paths.'
        return
    }

    foreach ($path in $attackPaths.PathList) {
        # The engine requires an instance ID matching ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$, so the ID is
        # the attack path type's GUID and the sentence Defender writes is the title.
        [pscustomobject]@{
            Id    = $path.AttackPathType
            Title = "No active attack path should exist: $($path.DisplayName)"
            Data  = $path
        }
    }
}

function Test-MtAzureDefenderForCloudAttackPath {
    <#
    .SYNOPSIS
    Ensure Microsoft Defender for Cloud reports no active attack path to a critical asset.

    .DESCRIPTION
    Defender CSPM correlates the weaknesses of an estate into attack paths: a chain that starts at
    something an attacker can reach and ends at something worth reaching. An individual recommendation
    rates each weakness on its own, and the path is what makes the combination matter.

    This check runs once per attack path Defender for Cloud reports, and fails for each one, because an
    attack path is by definition an active route rather than a configuration opinion. The result names
    the entry point's resource type, the target, the risk factors Defender combined, and the MITRE
    tactics the path covers.

    Severity follows the source: the risk level Defender assigns to the path.

    It never passes on an absent source. Without Defender CSPM on a readable subscription no path was
    ever computed, and the family reports that rather than a clean estate.

    .OUTPUTS
    [bool] - Always false for a reported path; null when the family is skipped.

    .EXAMPLE
    Test-MtAzureDefenderForCloudAttackPath

    Returns one result per attack path Defender for Cloud reports.

    .LINK
    https://maester.dev/docs/commands/Test-MtAzureDefenderForCloudAttackPath
    #>
    [MaesterTest(
        Id = 'MT.1258',
        Title = 'Microsoft Defender for Cloud should report no active attack path.',
        Product = 'azure',
        Feature = 'subscriptions',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Lifecycle = 'Preview',
        Service = 'Azure',
        InstanceSource = 'Get-MtAzureDefenderForCloudAttackPathInstance',
        Author = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The attack path to report, supplied by the engine.
        $Instance
    )

    $path = $Instance.Data

    # Severity follows the source, as #2510 asks: the risk level Defender assigns to the path.
    $severity = switch -Regex ([string]$path.RiskLevel) {
        '^(Critical|High)$' { 'High'; break }
        '^Medium$'          { 'Medium'; break }
        '^Low$'             { 'Low'; break }
        default             { 'High' }
    }

    $testResultMarkdown = "Defender for Cloud reports this attack path on **$($path.PathCount)** occasion(s).`n`n"
    $testResultMarkdown += "| Property | Value |`n| --- | --- |`n"
    if (-not [string]::IsNullOrWhiteSpace($path.RiskLevel)) { $testResultMarkdown += "| Risk level | $($path.RiskLevel) |`n" }

    $entry = @($path.EntryPointTypeList | Where-Object { $_ })
    if ($entry.Count -gt 0) { $testResultMarkdown += "| Entry point resource type | $($entry -join ', ') |`n" }
    $target = @($path.TargetList | Where-Object { $_ })
    if ($target.Count -gt 0) { $testResultMarkdown += "| Target | $($target -join ', ') |`n" }
    $targetType = @($path.TargetTypeList | Where-Object { $_ })
    if ($targetType.Count -gt 0) { $testResultMarkdown += "| Target resource type | $($targetType -join ', ') |`n" }

    $factors = @($path.RiskFactorList | Where-Object { $_ })
    if ($factors.Count -gt 0) { $testResultMarkdown += "`n**Risk factors Defender combined.** $($factors -join ', ')`n" }
    $tactics = @($path.TacticList | Where-Object { $_ })
    if ($tactics.Count -gt 0) { $testResultMarkdown += "`n**MITRE tactics.** $($tactics -join ', ')`n" }

    $testResultMarkdown += "`nBreak the path rather than every weakness on it. Removing the entry point's exposure, or the credential or permission that allows the step to the target, closes the whole route; Defender for Cloud lists the recommendations of this path in the Azure portal."

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity $severity
    return $false
}
