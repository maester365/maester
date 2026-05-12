# ZTA focus mechanism #1 — TAG-BASED selection.
#
# Each It body fetches fresh data via Get-MtZta (which self-heals from $env:ZTA_RESULTS_REF
# when Pester's runtime scope sees an empty MtZtaContext). This avoids the
# BeforeAll/BeforeDiscovery → It cross-scope issues that produce empty data and
# false-pass results.

Describe 'ZTA Identity focus — failed-pillar deep dive' -Tag 'ZTA' {

    It 'MT.Zta.1001: Identity pillar fail count is below the warn threshold. See https://maester.dev/docs/tests/MT.Zta.1001' -Tag 'MT.Zta.1001','Severity:High' {
        $zta     = Get-MtZta
        $summary = if ($zta) { Get-MtZta -Section Summary } else { $null }

        $description = @'
## What this test checks
ZTA's **Identity pillar** covers authentication methods, conditional access, sign-in risk, PIM coverage, and external-collaboration exposure. When more than 30 Identity-pillar tests fail, the most likely cause is a **policy-level regression** (e.g. baseline CA policy disabled, security defaults removed) rather than per-control drift. This test surfaces the bulk-failure signal before deeper per-bucket analysis.

## How to remediate
1. Open the ZTA report and sort the Identity pillar Tests[] by TestId.
2. Compare against a known-good configuration baseline.
3. Restore policy-level controls FIRST, then re-run ZTA, then resume per-finding remediation.
'@

        if (-not $summary) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 30
        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Identity Failed | **$($summary.IdentityFailed)** | $threshold |
| Identity Passed | $($summary.IdentityPassed) | — |
| Identity Skipped | $($summary.IdentitySkipped) | — |
| Identity Investigate | $($summary.IdentityInvestigate) | — |
| Fail ratio | $($summary.IdentityFailRatio) | (see MT.Zta.1002) |
"@

        Add-MtTestResultDetail -Description $description -Result $result

        $summary.IdentityFailed | Should -BeLessThan $threshold -Because (
            "ZTA flagged $($summary.IdentityFailed) Identity tests as Failed (ratio: $($summary.IdentityFailRatio))."
        )
    }

    It 'MT.Zta.1002: Identity fail ratio stays below 0.5 (50% of evaluated tests). See https://maester.dev/docs/tests/MT.Zta.1002' -Tag 'MT.Zta.1002','Severity:High' {
        $zta     = Get-MtZta
        $summary = if ($zta) { Get-MtZta -Section Summary } else { $null }

        $description = @'
## What this test checks
**Fail ratio = Failed / (Total - Skipped - Planned).** Skipped/Planned tests are excluded from the denominator so a fully-licensed pillar with 10 failures is comparable to an under-licensed pillar with 10 failures plus 50 skipped tests.

A ratio above 0.5 means **more than half** of evaluated Identity tests failed — a strong signal that core Identity posture is broken, not just drifting on individual controls.

## How to interpret
- 0.0–0.25 — healthy
- 0.25–0.5 — drift; review ZTA flagged categories
- 0.5+ — failing baseline; treat as an incident
'@

        if (-not $summary) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1002' -Default 0.5
        $ratio     = $summary.IdentityFailRatio
        $band   = if ($ratio -lt 0.25) { 'Healthy' } elseif ($ratio -lt 0.5) { 'Drift' } else { 'Failing' }
        $result = @"
| Metric | Value |
|---|---|
| **Fail ratio** | **$ratio** (threshold: $threshold) |
| Passed | $($summary.IdentityPassed) |
| Failed | $($summary.IdentityFailed) |
| Skipped | $($summary.IdentitySkipped) |
| Investigate | $($summary.IdentityInvestigate) |

Health band: **$band**
"@

        Add-MtTestResultDetail -Description $description -Result $result

        $ratio | Should -BeLessThan $threshold
    }

    It 'MT.Zta.1003: No PrivilegedAccess findings flagged users above the bar. See https://maester.dev/docs/tests/MT.Zta.1003' -Tag 'MT.Zta.1003','Severity:High','PIM','PrivilegedAccess' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
The **PrivilegedAccess** cross-cut bucket aggregates ZTA findings about role assignments, PIM eligibility, and credential management — across all four pillars (Identity / Devices / Network / Data). When more than 10 unique entries land in this bucket, role hygiene is the most cost-effective remediation lever.

## How to remediate
1. Open Entra ID → Privileged Identity Management → Roles → Assignments.
2. For each entry below: confirm whether the assignment is permanent (should be PIM-eligible), unmanaged (no review), or expired-but-still-active.
3. Convert permanent role assignments to PIM-eligible with access reviews.
'@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $buckets = @(Get-MtZta -Section FlaggedUsers)
        $priv = $buckets | Where-Object { $_.Category -eq 'PrivilegedAccess' } | Select-Object -First 1

        if (-not $priv) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No PrivilegedAccess bucket present in this run — either no failed tests in privileged-access categories, or CategoryMappings is missing the cross-cut rule.'
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1003' -Default 10
        $sample = ($priv.Group | Select-Object -First 5 | ForEach-Object {
            $upn = if ($_.UserPrincipalName) { $_.UserPrincipalName } else { '(no UPN)' }
            $id  = if ($_.UserId) { $_.UserId } else { '—' }
            "| $upn | $id | $($_.Pillar) |"
        }) -join "`n"

        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| PrivilegedAccess entries | **$($priv.Count)** | $threshold |
| Pillar | $($priv.Pillar) | — |

### Sample (first 5 of $($priv.Count))

| UPN | Id | Source pillar |
|---|---|---|
$sample
"@
        Add-MtTestResultDetail -Description $description -Result $result

        $priv.Count | Should -BeLessThan $threshold -Because (
            "ZTA bucketed $($priv.Count) entries into PrivilegedAccess. " +
            'Investigate role assignments and PIM eligibility coverage.'
        )
    }
}
