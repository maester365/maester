# ZTA operator-side drift + integration sanity tests.
# These verify the focus-mode plumbing and surface drift-vs-prior-run signal
# when the Maester stage's last-good fallback supplied an older bundle.

Describe 'ZTA operator drift checks' -Tag 'ZTA' {

    It 'MT.Zta.1010: Bundle freshness is within tolerance (warn-but-proceed band). See https://maester.dev/docs/tests/MT.Zta.1010' -Tag 'MT.Zta.1010','Severity:Medium','Drift' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
ZTA bundles older than `FreshnessDays` (default 14) are considered stale. `Test-MtZtaFreshness` warns and sets `IsStale = $true` on the context; this test surfaces that flag explicitly so the operator can see the staleness without inspecting every test's detail panel. The most common cause of staleness is the resolver step falling back to last-good after the current ZTA stage failed.

## How to remediate
1. Open the ZeroTrustAssessment stage logs from the current run.
2. Identify the failure root cause (auth, missing module, connectivity).
3. Re-run with `enableZtaExperimental=true` once the stage is healthy.
'@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $age = if ($zta.Freshness -and $null -ne $zta.Freshness.AgeDays) { [int]$zta.Freshness.AgeDays } else { -1 }
        $threshold = if ($zta.Freshness -and $zta.Freshness.PSObject.Properties['Threshold']) { [int]$zta.Freshness.Threshold } else { 14 }
        $source = if ($zta.Freshness -and $zta.Freshness.PSObject.Properties['TimestampSource']) { $zta.Freshness.TimestampSource } else { 'unknown' }

        $result = @"
| Field | Value |
|---|---|
| Bundle path | ``$($zta.BundlePath)`` |
| Age (days) | **$age** |
| Threshold | $threshold |
| Timestamp source | $source |
| IsStale flag | $($zta.IsStale) |
"@
        Add-MtTestResultDetail -Description $description -Result $result

        $zta.IsStale | Should -Be $false
    }

    It 'MT.Zta.1305: Severity overlay rule count + applied summary. See https://maester.dev/docs/tests/MT.Zta.1305' -Tag 'MT.Zta.1305','Severity:Low','SeverityOverlay' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
Smoke-tests the SeverityEscalationRules block by reporting how many rules exist and how many are wired with concrete selectors. This is mostly informational — failures of MT.Zta.1303 / 1304 already cover rule-shape correctness. This test exists to give the operator an at-a-glance summary in the report tab.

(Note: the actual escalation mutation runs inside `Update-MtSeverityFromZta` which is invoked from `Invoke-Maester`. PR-E does not yet wire that call from the customer pipeline — it lands once the upstream Maester PR adds the `-ZtaResultsPath` parameter natively.)
'@

        if (-not $zta -or -not $zta.PSObject.Properties['ZtaSettings'] -or -not $zta.ZtaSettings) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZtaSettings on context — overlay summary N/A.'
            return
        }

        $settings = $zta.ZtaSettings
        if (-not $settings.PSObject.Properties['SeverityEscalationRules'] -or -not $settings.SeverityEscalationRules) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No SeverityEscalationRules block in ZtaSettings.'
            return
        }

        $rules = @($settings.SeverityEscalationRules)
        $tagSelectors = @($rules | Where-Object { $_.PSObject.Properties['EscalateMaesterTagged'] -and $_.EscalateMaesterTagged }).Count
        $idSelectors  = @($rules | Where-Object { $_.PSObject.Properties['EscalateMaesterTestId']  -and $_.EscalateMaesterTestId  }).Count

        $result = @"
| Field | Value |
|---|---|
| Total rules | $($rules.Count) |
| Rules using tag selectors | $tagSelectors |
| Rules using TestId selectors | $idSelectors |

The actual mutation will run when Invoke-Maester gains the `-ZtaResultsPath` parameter (upstream PR).
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $rules.Count | Should -BeGreaterThan 0
    }

    It 'MT.Zta.1402: Get-MtZtaRecommendedTag produces a non-empty tag list. See https://maester.dev/docs/tests/MT.Zta.1402' -Tag 'MT.Zta.1402','Severity:Low','TagDerivation' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
Verifies that `Get-MtZtaRecommendedTag` (focus mechanism #1) emits a non-empty `[string[]]` of Maester tags derived from the loaded ZTA findings. When this is empty even though ZTA has failed tests, either the CategoryMappings block is missing matching rules or PillarTagMap is empty.

## How to remediate
1. Confirm `ZtaSettings.CategoryMappings` covers the pillars that have failed tests (4 pillar-level rules + 2 cross-cuts is the recommended baseline).
2. Verify `ZtaSettings.PillarTagMap` lists the Maester-side tag aliases for each pillar.
3. Re-run with `WarningAction Continue` to surface the ">10% Other" coverage warning if many tests classify into Other.
'@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $failed = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' })
        if ($failed.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No failed ZTA tests — recommended-tag set is correctly empty by design.'
            return
        }

        $tags = @(Get-MtZtaRecommendedTag -WarningAction SilentlyContinue)
        $sample = if ($tags) { ($tags | Sort-Object | Select-Object -First 20) -join ', ' } else { '(empty)' }

        $result = @"
| Metric | Value |
|---|---|
| Failed ZTA tests | $($failed.Count) |
| Derived tags | **$($tags.Count)** |

### Sample (first 20)

``$sample``
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $tags.Count | Should -BeGreaterThan 0
    }
}
