# ZTA focus mechanism #3 — DATA-DRIVEN matrix.
#
# Earlier version used Pester `-ForEach $buckets` to fan each per-bucket test
# out into one row per bucket category (so 1201 / 1202 / 1203 produced 6 rows
# each = 18 rows in the report). User feedback 2026-05-11: this was hard to
# scan in the test results table — too many near-identical rows for what is
# fundamentally one assertion per quality dimension. Refactored so each test
# emits exactly ONE row containing a per-bucket matrix inside
# `Add-MtTestResultDetail -Result`, and the assertion aggregates across all
# buckets ("ALL buckets must satisfy condition X").

Describe 'ZTA per-bucket user posture' -Tag 'ZTA' {

    It 'MT.Zta.1200: ZTA bucket family is populated. See https://maester.dev/docs/tests/MT.Zta.1200' -Tag 'MT.Zta.1200','Severity:Low' {
        $zta = Get-MtZta
        $buckets = if ($zta) { @(Get-MtZta -Section FlaggedUsers | Where-Object { $_.Count -gt 0 }) } else { @() }

        $description = @'
## What this test checks
Sentinel for the data-driven bucket family. Always emits one row so the family is visible in the report whether ZTA loaded or not, with a clear count of how many buckets were discovered.

`MT.Zta.1201` / `1202` / `1203` below evaluate quality dimensions across ALL populated buckets and render the per-bucket result as a matrix inside a single row each.
'@

        $rowsTable = if ($buckets) {
            ($buckets | ForEach-Object { "| $($_.Category) | $($_.Pillar) | $($_.Count) |" }) -join "`n"
        } else { '_no buckets — ZTA context not loaded or no flagged identities._' }

        $result = @"
| Category | Pillar | Pre-cap Count |
|---|---|---|
$rowsTable
"@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run; bucket family is empty by design.'
            return
        }

        Add-MtTestResultDetail -Description $description -Result $result
        $buckets.Count | Should -BeGreaterThan 0
    }

    It 'MT.Zta.1201: All populated buckets carry a non-empty Pillar. See https://maester.dev/docs/tests/MT.Zta.1201' -Tag 'MT.Zta.1201','Severity:Low' {
        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $buckets = @(Get-MtZta -Section FlaggedUsers | Where-Object { $_.Count -gt 0 })

        $description = @'
## What this test checks
Every populated bucket must carry a non-empty `Pillar` value (Identity / Devices / Network / Data) so downstream reporting can route findings to the right pillar owner. A null `Pillar` typically means a CategoryMappings rule was misconfigured (no `MatchPillar` value) — usually a category that ended up in `Other`.

The assertion aggregates across ALL populated buckets: every row in the matrix below must show a non-empty Pillar; the test fails only when at least one bucket has a missing Pillar.
'@

        if ($buckets.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No populated buckets — nothing to validate.'
            return
        }

        $offenders = @($buckets | Where-Object { -not $_.Pillar })

        $matrix = ($buckets | ForEach-Object {
            $ok = if ($_.Pillar) { 'yes' } else { 'NO — missing pillar' }
            "| $($_.Category) | $($_.Pillar) | $($_.Count) | $ok |"
        }) -join "`n"

        $result = @"
| Metric | Value |
|---|---|
| Populated buckets | $($buckets.Count) |
| Buckets with missing Pillar | **$($offenders.Count)** |

### Per-bucket result

| Category | Pillar | Pre-cap Count | Has Pillar? |
|---|---|---|---|
$matrix
"@

        Add-MtTestResultDetail -Description $description -Result $result
        $offenders.Count | Should -Be 0 -Because 'every populated bucket must declare a Pillar so findings are routable to the right owner'
    }

    It 'MT.Zta.1202: Across all buckets, Group sample size never exceeds pre-cap Count. See https://maester.dev/docs/tests/MT.Zta.1202' -Tag 'MT.Zta.1202','Severity:Low' {
        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $buckets = @(Get-MtZta -Section FlaggedUsers | Where-Object { $_.Count -gt 0 })

        $description = @'
## What this test checks
`Count` is the **pre-cap** total number of unique entities ZTA flagged for this category. `Group` is the (capped) sample of up to `MaxUsersPerCategory` entries. The sample size must never exceed the pre-cap total — a violation indicates a bucketing-logic bug in `Group-MtZtaFlaggedIdentity`.

The matrix below lists every populated bucket and whether its `MaxUsersPerCategory` cap was applied (sample size < pre-cap total). The assertion fails only when at least one bucket's Group is larger than its Count.
'@

        if ($buckets.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No populated buckets — nothing to validate.'
            return
        }

        $offenders = @($buckets | Where-Object { @($_.Group).Count -gt $_.Count })

        $matrix = ($buckets | ForEach-Object {
            $g = @($_.Group).Count
            $capApplied = if ($g -lt $_.Count) { 'yes' } else { 'no (within cap)' }
            $ok = if ($g -le $_.Count) { 'yes' } else { 'NO — Group exceeds Count' }
            "| $($_.Category) | $($_.Count) | $g | $capApplied | $ok |"
        }) -join "`n"

        $result = @"
| Metric | Value |
|---|---|
| Populated buckets | $($buckets.Count) |
| Buckets where Group > Count (bug) | **$($offenders.Count)** |

### Per-bucket result

| Category | Pre-cap Count | Group sample size | Cap applied | Group ≤ Count? |
|---|---|---|---|---|
$matrix
"@

        Add-MtTestResultDetail -Description $description -Result $result
        $offenders.Count | Should -Be 0 -Because 'no bucket sample (Group) may exceed the pre-cap Count; that would indicate a bug in Group-MtZtaFlaggedIdentity'
    }

    It 'MT.Zta.1203: Every bucket entry has UPN, UserId, or test-level evidence. See https://maester.dev/docs/tests/MT.Zta.1203' -Tag 'MT.Zta.1203','Severity:Medium' {
        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $buckets = @(Get-MtZta -Section FlaggedUsers | Where-Object { $_.Count -gt 0 })

        $description = @'
## What this test checks
Every entry in a ZTA-derived user bucket must carry at least one of: `UserPrincipalName`, `UserId`, or a non-empty `Evidence` array. An entry with all three null/empty is unactionable — the operator can't pivot to Entra ID, a sign-in log, or even know which ZTA TestId surfaced it. This catches regressions in user-extraction (UPN/GUID regex) or DuckDB enrichment.

The matrix below lists every populated bucket and the count of orphan entries (no UPN, no Id, no Evidence). The aggregate assertion fails only when any bucket has at least one orphan.
'@

        if ($buckets.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No populated buckets — nothing to validate.'
            return
        }

        $perBucket = foreach ($b in $buckets) {
            $orphans = @($b.Group | Where-Object {
                -not $_.UserPrincipalName -and -not $_.UserId -and (-not $_.Evidence -or $_.Evidence.Count -eq 0)
            })
            [pscustomobject]@{
                Category    = $b.Category
                GroupCount  = @($b.Group).Count
                OrphanCount = $orphans.Count
                Sample      = @($orphans | Select-Object -First 3)
            }
        }
        $totalOrphans = (@($perBucket | Measure-Object -Property OrphanCount -Sum).Sum)
        if ($null -eq $totalOrphans) { $totalOrphans = 0 }

        $matrix = ($perBucket | ForEach-Object {
            $ok = if ($_.OrphanCount -eq 0) { 'yes' } else { 'NO' }
            "| $($_.Category) | $($_.GroupCount) | $($_.OrphanCount) | $ok |"
        }) -join "`n"

        $offenderSample = @($perBucket | Where-Object { $_.OrphanCount -gt 0 })
        $orphanSample = if ($offenderSample.Count -gt 0) {
            ($offenderSample | ForEach-Object {
                $cat = $_.Category
                ($_.Sample | ForEach-Object {
                    "| $cat | $(@($_.Evidence).Count) |"
                }) -join "`n"
            }) -join "`n"
        } else { '_none — every entry is actionable._' }

        $result = @"
| Metric | Value |
|---|---|
| Populated buckets | $($buckets.Count) |
| Orphan entries across all buckets | **$totalOrphans** |

### Per-bucket result

| Category | Group sample size | Orphan entries | All actionable? |
|---|---|---|---|
$matrix

### Orphan sample (up to 3 per affected bucket)

| Bucket | Evidence count |
|---|---|
$orphanSample
"@

        Add-MtTestResultDetail -Description $description -Result $result
        $totalOrphans | Should -Be 0 -Because 'an entry with no UPN, no UserId, and no evidence is unactionable'
    }
}
