function Get-MtZtaRecommendedTag {
    <#
    .SYNOPSIS
        Derives a Pester `-Tag` list from current ZTA findings so Maester runs only the tests
        relevant to the areas ZTA flagged.

    .DESCRIPTION
        Walks `$script:MtZtaContext.Tests` (failed entries only), classifies each into a bucket
        per `ZtaSettings.CategoryMappings`, and emits the union of `MaesterTagBoost` arrays
        plus the literal pillar names as a `[string[]]`.

        Defaults when no `ZtaSettings` is present on the context:
          - `PillarTagMap` falls back to a vendor-neutral baseline that mirrors the pillar
            keywords already used in upstream Maester tests
            (Identity, Devices, Network, Data, MFA, ConditionalAccess, PIM, Intune, Compliance, ...).
          - `CategoryMappings` empty -> all failures classify as 'Other' (no boost tags emitted).

        Returns an empty array when ZTA was not loaded or has no failures.

        **Coverage warning:** if more than 10 % of failed tests classify as `Other`, the cmdlet
        emits a `Write-Warning` so the operator can revisit the CategoryMappings block.

    .EXAMPLE
        $tags = Get-MtZtaRecommendedTag
        Invoke-Maester -Tag $tags

    .LINK
        https://maester.dev/docs/commands/Get-MtZtaRecommendedTag

    .LINK
        https://maester.dev/docs/zero-trust-assessment
    #>
    [CmdletBinding()]
    [OutputType([string[]], [object[]])]
    param()

    if (-not $script:MtZtaContext) {
        Write-Verbose 'Get-MtZtaRecommendedTag: $script:MtZtaContext is not set. Returning empty array.'
        return @()
    }

    $tests  = @($script:MtZtaContext.Tests)
    $failed = @($tests | Where-Object { $_.TestStatus -eq 'Failed' })
    if ($failed.Count -eq 0) {
        Write-Verbose 'Get-MtZtaRecommendedTag: no failed ZTA tests; returning empty tag list.'
        return @()
    }

    $settings = $script:MtZtaContext.ZtaSettings

    # CategoryMappings — required for boost tags; empty array gracefully degrades.
    $mappings = @()
    if ($settings -and $settings.PSObject.Properties['CategoryMappings'] -and $settings.CategoryMappings) {
        $mappings = @($settings.CategoryMappings)
    }

    # PillarTagMap — pillar literals + their Maester-side aliases. Defaults mirror the
    # tag conventions already used in tests/Maester/* so this works without any config block.
    $pillarTagMap = @{
        Identity = @('Identity','EID','MFA','ConditionalAccess','PIM')
        Devices  = @('Intune','Device','Compliance','Defender')
        Network  = @('Network','GlobalSecureAccess','GSA')
        Data     = @('Exchange','SharePoint','Purview','Sensitivity')
    }
    if ($settings -and $settings.PSObject.Properties['PillarTagMap'] -and $settings.PillarTagMap) {
        # Merge over defaults — operator overrides win, missing pillars keep defaults.
        foreach ($p in $settings.PillarTagMap.PSObject.Properties.Name) {
            $pillarTagMap[$p] = @($settings.PillarTagMap.$p)
        }
    }

    $tags = New-Object System.Collections.Generic.HashSet[string]
    $otherCount = 0

    foreach ($t in $failed) {
        # 1. Pillar literal + pillar's Maester-tag aliases
        if ($t.TestPillar) {
            [void]$tags.Add([string]$t.TestPillar)
            if ($pillarTagMap.ContainsKey([string]$t.TestPillar)) {
                foreach ($a in $pillarTagMap[[string]$t.TestPillar]) { [void]$tags.Add($a) }
            }
        }

        # 2. Category mapping -> MaesterTagBoost
        $cat = Get-MtZtaCategoryForTest -Test $t -CategoryMappings $mappings
        if ($cat -eq 'Other') {
            $otherCount++
            continue
        }

        $rule = $mappings | Where-Object {
            if ($_ -is [System.Collections.IDictionary]) { $_['Category'] -eq $cat } else { $_.Category -eq $cat }
        } | Select-Object -First 1
        if ($rule) {
            $boostValue = if ($rule -is [System.Collections.IDictionary]) {
                $rule['MaesterTagBoost']
            } elseif ($rule.PSObject.Properties['MaesterTagBoost']) {
                $rule.MaesterTagBoost
            } else { $null }
            if ($boostValue) {
                foreach ($boost in @($boostValue)) { [void]$tags.Add([string]$boost) }
            }
        }
    }

    if ($failed.Count -gt 0) {
        $otherRatio = $otherCount / $failed.Count
        if ($otherRatio -gt 0.10) {
            Write-Warning ("Get-MtZtaRecommendedTag: {0} of {1} failed tests ({2:P0}) fell into the 'Other' bucket. " +
                           "Consider adding categories to ZtaSettings.CategoryMappings to improve focus." `
                           -f $otherCount, $failed.Count, $otherRatio)
        }
    }

    # Deterministic ordering for reproducible Invoke-Maester -Tag invocations.
    return @($tags | Sort-Object)
}
