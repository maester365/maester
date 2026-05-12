function Update-MtSeverityFromZta {
    <#
    .SYNOPSIS
        Mutates an in-memory `TestSettings[]` array per `ZtaSettings.SeverityEscalationRules`
        before Pester discovery, so ZTA findings can escalate severity on matching Maester tests.

    .DESCRIPTION
        Reads `$script:MtZtaContext.ZtaSettings.SeverityEscalationRules`, evaluates each rule
        against the loaded context, and mutates entries in `-TestSettings` whose `Id` or `Tag`
        matches an active rule's selector.

        Rule shape:
          {
            "WhenPillarFailedAtLeast": <int>,           // count of Failed tests in pillar
            "WhenCategoryFlaggedUsersAtLeast": <int>,   // count of users in CategoryMappings bucket
            "Pillar": "<Identity|Devices|Network|Data>",
            "Category": "<bucket name from CategoryMappings>",
            "EscalateMaesterTagged": ["<tag>", ...],    // selector — match TestSetting.Tag
            "EscalateMaesterTestId": ["<id>", ...],     // selector — match TestSetting.Id (wildcards allowed)
            "From": "<severity>",                        // optional — only escalate if current severity == From
            "To": "<severity>"
          }

        Idempotent — running twice does not double-escalate (the second run finds severity
        already at the target). Safe to call before Pester discovery on each `Invoke-Maester`.

        No-op when `$script:MtZtaContext` is unset, ZtaSettings is missing, or no rules fire.

    .PARAMETER TestSettings
        The TestSettings array from `maester-config.json` (already deserialised to PSObject).
        Mutated in place AND returned for pipeline-style chaining.

    .EXAMPLE
        $cfg = Get-Content maester-config.json -Raw | ConvertFrom-Json
        Import-MtZtaResult -ZtaResultsPath .\zta -ZtaSettings $cfg.ZtaSettings
        $cfg.TestSettings = Update-MtSeverityFromZta -TestSettings $cfg.TestSettings

    .LINK
        https://maester.dev/docs/commands/Update-MtSeverityFromZta

    .LINK
        https://maester.dev/docs/zero-trust-assessment
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]] $TestSettings
    )

    if (-not $script:MtZtaContext) {
        Write-Verbose 'Update-MtSeverityFromZta: $script:MtZtaContext is not set. TestSettings unchanged.'
        return $TestSettings
    }

    $settings = $script:MtZtaContext.ZtaSettings
    if (-not $settings -or -not $settings.PSObject.Properties['SeverityEscalationRules'] -or -not $settings.SeverityEscalationRules) {
        Write-Verbose 'Update-MtSeverityFromZta: no SeverityEscalationRules configured. TestSettings unchanged.'
        return $TestSettings
    }

    $rules = @($settings.SeverityEscalationRules)
    $tests = @($script:MtZtaContext.Tests)

    # Pre-compute pillar fail counts once per call.
    $pillarFailCounts = @{}
    foreach ($p in 'Identity','Devices','Network','Data') {
        $pillarFailCounts[$p] = @($tests | Where-Object { $_.TestPillar -eq $p -and $_.TestStatus -eq 'Failed' }).Count
    }

    # Pre-compute category bucket sizes (cheaper than calling Group-MtZtaFlaggedIdentity per rule).
    $mappings = @()
    if ($settings.PSObject.Properties['CategoryMappings'] -and $settings.CategoryMappings) {
        $mappings = @($settings.CategoryMappings)
    }
    $categoryUserCounts = @{}
    if ($mappings.Count -gt 0) {
        $buckets = Get-MtZta -Section FlaggedUsers
        foreach ($b in $buckets) { $categoryUserCounts[$b.Category] = [int]$b.Count }
    }

    $mutationCount = 0
    foreach ($rule in $rules) {
        # Evaluate conditions — rule fires if ALL specified conditions hold.
        $fires = $true

        if ($rule.PSObject.Properties['WhenPillarFailedAtLeast'] -and $rule.PSObject.Properties['Pillar']) {
            $threshold = [int]$rule.WhenPillarFailedAtLeast
            $pillar    = [string]$rule.Pillar
            $actual    = if ($pillarFailCounts.ContainsKey($pillar)) { $pillarFailCounts[$pillar] } else { 0 }
            if ($actual -lt $threshold) { $fires = $false }
        }

        if ($fires -and $rule.PSObject.Properties['WhenCategoryFlaggedUsersAtLeast'] -and $rule.PSObject.Properties['Category']) {
            $threshold = [int]$rule.WhenCategoryFlaggedUsersAtLeast
            $category  = [string]$rule.Category
            $actual    = if ($categoryUserCounts.ContainsKey($category)) { $categoryUserCounts[$category] } else { 0 }
            if ($actual -lt $threshold) { $fires = $false }
        }

        if (-not $fires) { continue }

        # Build the selector predicate.
        $tagSelectors = @()
        if ($rule.PSObject.Properties['EscalateMaesterTagged'] -and $rule.EscalateMaesterTagged) {
            $tagSelectors = @($rule.EscalateMaesterTagged | ForEach-Object { [string]$_ })
        }
        $idSelectors = @()
        if ($rule.PSObject.Properties['EscalateMaesterTestId'] -and $rule.EscalateMaesterTestId) {
            $idSelectors = @($rule.EscalateMaesterTestId | ForEach-Object { [string]$_ })
        }
        if (-not $tagSelectors -and -not $idSelectors) {
            Write-Verbose "Update-MtSeverityFromZta: rule has no Escalate* selector — skipping."
            continue
        }

        $fromSeverity = if ($rule.PSObject.Properties['From']) { [string]$rule.From } else { $null }
        $toSeverity   = [string]$rule.To
        if (-not $toSeverity) {
            Write-Warning 'Update-MtSeverityFromZta: rule missing To severity; skipping.'
            continue
        }

        foreach ($ts in $TestSettings) {
            if (-not $ts.PSObject.Properties['Id']) { continue }

            # Match by TestId (wildcards) OR by Tag.
            $matched = $false
            foreach ($pat in $idSelectors) {
                if ([string]$ts.Id -like $pat) { $matched = $true; break }
            }
            if (-not $matched -and $tagSelectors -and $ts.PSObject.Properties['Tag'] -and $ts.Tag) {
                $tsTags = @($ts.Tag | ForEach-Object { [string]$_ })
                foreach ($want in $tagSelectors) {
                    if ($tsTags -contains $want) { $matched = $true; break }
                }
            }
            if (-not $matched) { continue }

            # Apply severity floor: only escalate if current severity == From (when From set)
            # AND new severity is strictly higher in the M->H->C ladder.
            $currentSeverity = if ($ts.PSObject.Properties['Severity']) { [string]$ts.Severity } else { $null }
            if ($fromSeverity -and $currentSeverity -ne $fromSeverity) { continue }
            if (-not (Test-MtZtaSeverityHigher -From $currentSeverity -To $toSeverity)) { continue }

            if ($PSCmdlet.ShouldProcess("$($ts.Id) (current: $currentSeverity)", "Escalate severity to $toSeverity")) {
                if ($ts.PSObject.Properties['Severity']) {
                    $ts.Severity = $toSeverity
                }
                else {
                    Add-Member -InputObject $ts -MemberType NoteProperty -Name Severity -Value $toSeverity -Force
                }
                $mutationCount++
            }
        }
    }

    if ($mutationCount -gt 0) {
        Write-Verbose "Update-MtSeverityFromZta: escalated severity on $mutationCount TestSettings entries."
    }

    return $TestSettings
}

function Test-MtZtaSeverityHigher {
    <#
    .SYNOPSIS
        Internal: returns $true when -To is strictly higher than -From in Maester's
        severity ladder (Info < Low < Medium < High < Critical).

    .DESCRIPTION
        Used by Update-MtSeverityFromZta to enforce monotonic-up escalation — the cmdlet
        never lowers severity. Unknown severities (custom strings) collate at 0 so any
        recognised target severity will replace them.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string] $From,
        [Parameter(Mandatory = $true)] [string] $To
    )
    $rank = @{ 'Info' = 1; 'Low' = 2; 'Medium' = 3; 'High' = 4; 'Critical' = 5 }
    $f = if ($From -and $rank.ContainsKey($From)) { $rank[$From] } else { 0 }
    $t = if ($rank.ContainsKey($To))             { $rank[$To] }   else { 0 }
    return ($t -gt $f)
}
