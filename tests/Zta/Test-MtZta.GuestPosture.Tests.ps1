# ZTA focus mechanism #2 — CONDITIONAL `It` (gate inside body).
#
# Pester 5 BeforeDiscovery → It cross-scope variables don't reliably survive in some
# Pester runtime configurations (Invoke-InNewScriptScope), so each It body fetches
# fresh data via Get-MtZta directly. Get-MtZta self-heals from $env:ZTA_RESULTS_REF
# when context is null, making this pattern robust regardless of scope behaviour.

Describe 'ZTA Guest posture — runs only when guest exposure is significant' -Tag 'ZTA' {

    It 'MT.Zta.1101: Identity fail ratio is high enough to warrant guest deep-dive. See https://maester.dev/docs/tests/MT.Zta.1101' `
       -Tag 'MT.Zta.1101','Severity:Medium' {
        # Gate evaluated INSIDE the body so Add-MtTestResultDetail always runs and the
        # report shows WHY the test skipped, not just a blank Skipped row.
        $zta     = Get-MtZta
        $summary = if ($zta) { Get-MtZta -Section Summary } else { $null }
        $ratio   = if ($summary) { $summary.IdentityFailRatio } else { 0 }

        $description = @'
## What this test checks
**Gate test.** Runs only when the Identity-pillar fail ratio is **≥ 0.5** — the threshold below which deep-dive analysis isn't cost-effective. When this test is reported as Passed, it means ZTA found enough Identity failures that the per-bucket guest-posture tests below carry meaningful signal.

## How to interpret
- Skipped — Identity posture is healthy enough that guest-specific deep-dive isn't warranted.
- Passed — Identity fail ratio crossed the gate; review the GuestUnconstrained tests (1102, 1103) for actionable detail.
'@

        $result = @"
| Metric | Value | Gate |
|---|---|---|
| Identity fail ratio | $ratio | ≥ 0.5 |
| Identity Failed | $(if ($summary) { $summary.IdentityFailed } else { '—' }) | — |
| Identity Passed | $(if ($summary) { $summary.IdentityPassed } else { '—' }) | — |
"@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        if ($ratio -lt 0.5) {
            Add-MtTestResultDetail -Description $description -Result $result -SkippedBecause Custom -SkippedCustomReason "Identity fail ratio $ratio is below the 0.5 deep-dive threshold — guest-specific tests aren't cost-effective on a healthy Identity baseline. **This is wanted behaviour**: the gate is by design and means the tenant's Identity posture is healthy enough that guest deep-dive doesn't add signal."
            return
        }

        Add-MtTestResultDetail -Description $description -Result $result
        $ratio | Should -BeGreaterOrEqual 0.5
    }

    It 'MT.Zta.1102: GuestUnconstrained bucket has fewer than 25 entries. See https://maester.dev/docs/tests/MT.Zta.1102' -Tag 'MT.Zta.1102','Severity:High' {
        $zta = Get-MtZta
        $description = @'
## What this test checks
The **GuestUnconstrained** cross-cut groups guest accounts that ZTA flagged as having weak external-collaboration controls — typically guests outside conditional-access scope, with no compliant device, or never used yet still enabled.

A bucket with more than 25 entries indicates **systemic guest-lifecycle drift**, not isolated cases. Address policy first (CA exclusions, lifecycle workflows, access reviews) before per-guest cleanup.

## How to remediate
1. Entra ID → External Identities → External collaboration settings — review guest invite restrictions.
2. Entra ID → Identity Governance → Access Reviews — ensure recurring reviews on guest membership.
3. Conditional Access — verify a guest-targeted policy enforces MFA + device compliance.
'@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $bucket = @(Get-MtZta -Section FlaggedUsers) | Where-Object { $_.Category -eq 'GuestUnconstrained' } | Select-Object -First 1
        if (-not $bucket) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No GuestUnconstrained bucket present in this run — no failed tests in guest-related categories.'
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1102' -Default 25
        $sample = ($bucket.Group | Select-Object -First 10 | ForEach-Object {
            $upn = if ($_.UserPrincipalName) { $_.UserPrincipalName } else { '(no UPN)' }
            $id  = if ($_.UserId) { $_.UserId } else { '—' }
            "| $upn | $id |"
        }) -join "`n"

        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| GuestUnconstrained entries | **$($bucket.Count)** | $threshold |

### Sample (first 10 of $($bucket.Count))

| UPN | Id |
|---|---|
$sample
"@

        Add-MtTestResultDetail -Description $description -Result $result

        $bucket.Count | Should -BeLessThan $threshold -Because (
            "ZTA flagged $($bucket.Count) guests as unconstrained. " +
            'Review external-collaboration policy and conditional-access coverage.'
        )
    }

    It 'MT.Zta.1103: GuestUnconstrained bucket entries each carry evidence. See https://maester.dev/docs/tests/MT.Zta.1103' -Tag 'MT.Zta.1103','Severity:Medium' {
        $zta = Get-MtZta
        $description = @'
## What this test checks
Every entry in the **GuestUnconstrained** bucket should carry at least one Evidence string explaining *why* it was flagged (which ZTA TestId surfaced it, or which DuckDB enrichment query). Entries with no evidence are unactionable and indicate a CategoryMappings or extraction bug.

## How to interpret
- Passed — every flagged guest has at least one evidence entry.
- Failed — at least one guest landed in this bucket without evidence; investigate CategoryMappings or `Group-MtZtaFlaggedIdentity` parsing logic.
'@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $bucket = @(Get-MtZta -Section FlaggedUsers) | Where-Object { $_.Category -eq 'GuestUnconstrained' } | Select-Object -First 1
        if (-not $bucket) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No GuestUnconstrained bucket present in this run.'
            return
        }

        $missing = @($bucket.Group | Where-Object { -not $_.Evidence -or @($_.Evidence).Count -eq 0 })
        $sample = if ($missing) {
            ($missing | Select-Object -First 5 | ForEach-Object {
                $upn = if ($_.UserPrincipalName) { $_.UserPrincipalName } else { '(no UPN)' }
                "| $upn | $($_.UserId) |"
            }) -join "`n"
        } else { '_none — every entry has at least one evidence string._' }

        $result = @"
| Metric | Value |
|---|---|
| Total bucket entries | $($bucket.Count) |
| Entries missing evidence | **$($missing.Count)** |

### Entries with no evidence (sample of 5)

| UPN | Id |
|---|---|
$sample
"@

        Add-MtTestResultDetail -Description $description -Result $result

        $missing.Count | Should -Be 0
    }
}
