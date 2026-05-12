# Lifecycle hygiene gap-fill — when ZTA flags inactive guests, app-credential
# rotation, or stale users, verify whether lifecycle policy / access reviews /
# secret rotation actually catch these via Reader queries (Tier 2 DuckDB or
# Tier 1 JSON shadow — whichever is loaded).
#
# These tests COMPLEMENT (not duplicate) the existing Maester checks:
#   - MT.1029 (privileged-only stale users) → MT.Zta.1170 covers ALL users
#   - MT.1057 (app secrets exist) → MT.Zta.1160 covers secret AGE
#   - MT.1016 (guest CA exists) → MT.Zta.1150 covers inactive-guests-with-creds
#
# ZTA TestId triggers used in this file:
#
#   21772  Identity / Application management
#          Applications don't have client secrets configured
#   21858  Identity / External collaboration
#          Inactive guest identities are disabled or removed from the tenant
#   21874  Identity / External collaboration
#          Guest access is limited to approved tenants
#   21992  Identity / Application management
#          Application certificates must be rotated on a regular basis
#
# References:
#   ZTA project        https://microsoft.github.io/zerotrustassessment/
#   Microsoft Learn    https://learn.microsoft.com/security/zero-trust/assessment/

Describe 'ZTA lifecycle hygiene' -Tag 'ZTA' {

    It 'MT.Zta.1150: Inactive guest accounts with active credentials. See https://maester.dev/docs/tests/MT.Zta.1150' `
       -Tag 'MT.Zta.1150','Severity:High','Identity','Guest','Lifecycle' {

        $description = @'
## What this test checks
Streams the ZTA `User` table (where `userType='Guest'` AND `accountEnabled=true`) and surfaces guests whose most-recent successful sign-in is older than 90 days. Each one is a potential phishing target.

ZTA [`21858`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21858.md) flags this category at policy level; MT.Zta.1150 enumerates the actual users so the operator can take action without leaving the report.

## How to remediate
1. Entra ID → Identity Governance → Access Reviews — set up a recurring review on the guest user set.
2. Entra ID → External Identities → Lifecycle workflow — auto-disable inactive guests after 90 days of no sign-in.
3. For ad-hoc cleanup: disable each listed guest, then delete after a grace period.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('21858','21874') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 21858 (inactive guests disabled/removed) or 21874 (guest tenant restriction) — both are Passed in this run, so the inactive-guests-with-active-creds enumeration is N/A. **This is wanted behaviour**: ZTA already verified guest hygiene at policy level; the per-account follow-up only fires when ZTA detected the underlying weakness."
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            $cutoff = (Get-Date).ToUniversalTime().AddDays(-90)
            $stale = New-Object System.Collections.Generic.List[object]
            & $reader.GetRows 'User' { param($u)
                if ($u.userType -ne 'Guest') { return $false }
                if (-not $u.accountEnabled) { return $false }
                # ZTA flattens nested signInActivity into snake_case columns. Some
                # exports preserve the camel-case nested shape; probe both.
                $lastRaw = $null
                if ($u.PSObject.Properties['signInActivity_lastSignInDateTime']) {
                    $lastRaw = $u.signInActivity_lastSignInDateTime
                } elseif ($u.PSObject.Properties['signInActivity']) {
                    $lastRaw = $u.signInActivity.lastSignInDateTime
                }
                if (-not $lastRaw) { return $true }   # never signed in -> stale
                try { $dt = [datetime]::Parse([string]$lastRaw).ToUniversalTime() } catch { return $true }
                return $dt -lt $cutoff
            } | ForEach-Object {
                $stale.Add([pscustomobject]@{
                    id = $_.id
                    userPrincipalName = $_.userPrincipalName
                    displayName = $_.displayName
                    mail = $_.mail
                })
                if ($stale.Count -ge 50) { return }
            }
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1150' -Default 5
$sample = if ($stale.Count -gt 0) {
            ($stale | Select-Object -First 10 | ForEach-Object {
                "| $($_.userPrincipalName) | $($_.displayName) | $($_.mail) |"
            }) -join "`n"
        } else { '_none — every active guest has signed in in the last 90 days._' }

        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Inactive guests with active accounts | **$($stale.Count)** | $threshold |

### Sample (first 10)

| UPN | Display name | Mail |
|---|---|---|
$sample
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $stale.Count | Should -BeLessThan $threshold
    }

    It 'MT.Zta.1160: Application credentials older than 1 year. See https://maester.dev/docs/tests/MT.Zta.1160' `
       -Tag 'MT.Zta.1160','Severity:Critical','Identity','Apps','Lifecycle' {

        $description = @'
## What this test checks
Inspects `Application.passwordCredentials` (a JSON-array column) and reports apps where any credential's `endDateTime - startDateTime` exceeds 365 days. Long-lived secrets are the canonical phishing-resistant-bypass vector — short rotation cadence is the compensating control ZTA [`21992`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21992.md) flags as missing.

Findings are split into two buckets:

- **Never-expiring secrets** (Critical) — credentials whose `endDateTime` is the year-9999 sentinel (or any lifetime > 50 years). These are higher severity than long-but-finite lifetimes because there is no remediation deadline at all; once leaked, the credential is valid forever. Treat each as an open incident.
- **Long-lived secrets** (Medium) — credentials with `endDateTime - startDateTime > 365 days` but a real expiry. Lower severity because they self-mitigate at expiry, but still drift well outside policy.

## How to remediate
1. **Never-expiring secrets first** — Entra ID → Application registrations → filter by app — regenerate with a real expiry (≤ 90 days), then revoke the old one. Treat as an open incident; assume the secret is in scope of any past compromise.
2. Replace client secrets with **certificate** auth or **federated credentials** (workload identity federation) where possible — both eliminate long-lived secrets entirely.
3. Set an app-management policy enforcing max secret lifetime (90 days) tenant-wide.

## Related Maester core tests (read together)
This test is the **warn-band** for app-credential hygiene. The Maester core family has a stricter pass/fail bar (no static secrets at all) plus operational reminders that overlap in intent:

- ``MT.1057`` — *App registrations should no longer use secrets* (cert-only / federated-credentials). Strict pass/fail: any password credential fails. **Stricter target than 1160.**
- ``MT.1024.applicationCredentialExpiry`` — *Renew expiring application credentials*. Closest sibling — surfaces near-expiry credentials so they don't lapse silently. Operational reminder; not a strict gate.
- ``MT.1024.staleAppCreds`` — *Remove unused credentials from applications*. Catches credentials that exist but haven't been used recently. Orthogonal.
- ``MT.1077`` / ``MT.1078`` — *App registrations with privileged API permissions / directory roles should not have …* — additional risk overlays for high-impact apps.

**Joint reading**:

- ``MT.1057`` Failed + ``MT.Zta.1160`` Failed → secrets exist AND some are long-lived/never-expiring. **1160 lists the urgent ones to rotate first; MT.1057 is the long-term target (move to cert / federated identity).**
- ``MT.1057`` Failed + ``MT.Zta.1160`` Passed → secrets exist but all have reasonable lifetimes (≤ 1y). The cleanup is operational hygiene, not an incident.
- ``MT.1057`` Passed + ``MT.Zta.1160`` Passed → cert-only / federated tenant. ✅ ideal end-state.
- ``MT.1057`` Passed but ``MT.Zta.1160`` Failed should be impossible (1160 only fires when secrets exist); if it happens, file a bug.

Treat ``MT.Zta.1160`` Critical findings (year-9999 secrets) as incidents regardless of ``MT.1057`` status.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('21992','21772') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 21992/21772 — gap-fill not applicable."
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            # Never-expiring sentinel: Graph emits 9999-12-31T23:59:59Z (or similar
            # 9000+ year) for credentials with no real expiry. Treat any lifetime
            # > 50 years (~18250 days) as the sentinel bucket regardless of exact
            # value, since we've observed both year-9999 and other absurdly-future
            # endDateTime patterns in real tenants.
            $sentinelDays = 50 * 365   # 18250
            $neverExpiring = New-Object System.Collections.Generic.List[object]
            $longLived     = New-Object System.Collections.Generic.List[object]
            & $reader.GetRows 'Application' | ForEach-Object {
                $app = $_
                $maxDays = 0
                $maxEnd  = $null
                $creds = if ($app.passwordCredentials) { @($app.passwordCredentials) } else { @() }
                foreach ($c in $creds) {
                    if (-not $c.startDateTime -or -not $c.endDateTime) { continue }
                    try {
                        $start = [datetime]::Parse([string]$c.startDateTime).ToUniversalTime()
                        $end   = [datetime]::Parse([string]$c.endDateTime).ToUniversalTime()
                        $days  = ($end - $start).TotalDays
                        if ($days -gt $maxDays) { $maxDays = [int]$days; $maxEnd = $end }
                    } catch { }
                }
                if ($maxDays -le 365) { return }
                $row = [pscustomobject]@{
                    appId = $app.appId
                    displayName = $app.displayName
                    maxLifetimeDays = $maxDays
                    maxEndDateTime = if ($maxEnd) { $maxEnd.ToString('yyyy-MM-dd') } else { $null }
                }
                if ($maxDays -gt $sentinelDays) {
                    $neverExpiring.Add($row)
                } else {
                    $longLived.Add($row)
                }
            }
            $neverExpiring = @($neverExpiring | Sort-Object maxLifetimeDays -Descending | Select-Object -First 50)
            $longLived     = @($longLived     | Sort-Object maxLifetimeDays -Descending | Select-Object -First 50)
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $neverExpiringSample = if ($neverExpiring.Count -gt 0) {
            ($neverExpiring | Select-Object -First 10 | ForEach-Object {
                "| $($_.displayName) | $($_.appId) | $($_.maxEndDateTime) |"
            }) -join "`n"
        } else { '_none — no apps have never-expiring secrets._' }
        $longLivedSample = if ($longLived.Count -gt 0) {
            ($longLived | Select-Object -First 10 | ForEach-Object {
                "| $($_.displayName) | $($_.appId) | $($_.maxLifetimeDays) | $($_.maxEndDateTime) |"
            }) -join "`n"
        } else { '_none — every other app secret has a lifetime ≤ 1 year._' }

        $result = @"
| Severity | Metric | Value |
|---|---|---|
| **Critical** | Apps with **never-expiring** secrets (sentinel year-9999 or > 50y lifetime) | **$($neverExpiring.Count)** |
| Medium | Apps with secrets > 1y lifetime (finite expiry) | **$($longLived.Count)** |

### Critical: never-expiring secrets (first 10)

| App displayName | appId | endDateTime |
|---|---|---|
$neverExpiringSample

### Long-lived but finite secrets (first 10, sorted by max lifetime desc)

| App displayName | appId | Max lifetime (days) | endDateTime |
|---|---|---|---|
$longLivedSample
"@
        Add-MtTestResultDetail -Description $description -Result $result
        ($neverExpiring.Count + $longLived.Count) | Should -Be 0
    }

    It 'MT.Zta.1170: Stale non-privileged users with active accounts. See https://maester.dev/docs/tests/MT.Zta.1170' `
       -Tag 'MT.Zta.1170','Severity:Medium','Identity','Lifecycle','StaleUser' {

        $description = @'
## What this test checks
Maester `MT.1029` covers stale **privileged** users via PIM alerts. This gap-fill extends the check to **non-privileged** users — the population PIM alerts ignore but which still represent ~80%+ of typical tenant identity sprawl. Streams `User` ⨝ anti-join with `RoleAssignment` and filters to `accountEnabled=true` AND last-sign-in older than 90 days.

**Break-glass exclusion**: accounts listed in `GlobalSettings.EmergencyAccessAccounts` are excluded — break-glass accounts intentionally lack recent sign-ins.

## How to remediate
1. Identity Governance → Access Reviews — recurring review on all-users, auto-disable on no response.
2. Lifecycle workflow → trigger join/leave/mover automation for HR-driven changes.
3. For one-time cleanup: bulk-disable the listed accounts, then delete after grace period.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $summary = Get-MtZta -Section Summary
        if (-not $summary -or $summary.IdentityFailed -lt 5) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA Identity-pillar Failed count ($(if ($summary) { $summary.IdentityFailed } else { 'n/a' })) below the trigger threshold (5) — gap-fill not applicable."
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            # Build privileged-id index from RoleAssignment.
            $privilegedIds = @{}
            $raRows = & $reader.GetRows 'RoleAssignment'
            foreach ($r in $raRows) { if ($r.principalId) { $privilegedIds[[string]$r.principalId] = $true } }

            $cutoff = (Get-Date).ToUniversalTime().AddDays(-90)
            $stale = New-Object System.Collections.Generic.List[object]
            $excludedBreakGlass = 0
            & $reader.GetRows 'User' { param($u)
                if ($u.userType -ne 'member') { return $false }
                if (-not $u.accountEnabled) { return $false }
                if ($u.id -and $privilegedIds.ContainsKey([string]$u.id)) { return $false }
                $lastRaw = $null
                if ($u.PSObject.Properties['signInActivity_lastSignInDateTime']) {
                    $lastRaw = $u.signInActivity_lastSignInDateTime
                } elseif ($u.PSObject.Properties['signInActivity']) {
                    $lastRaw = $u.signInActivity.lastSignInDateTime
                }
                if (-not $lastRaw) { return $true }
                try { $dt = [datetime]::Parse([string]$lastRaw).ToUniversalTime() } catch { return $true }
                return $dt -lt $cutoff
            } | ForEach-Object {
                # Break-glass accounts intentionally lack recent sign-ins — exclude.
                if (Test-MtZtaIsEmergencyAccess -Id $_.id -UserPrincipalName $_.userPrincipalName) {
                    $excludedBreakGlass++
                    return
                }
                $stale.Add([pscustomobject]@{
                    id = $_.id
                    userPrincipalName = $_.userPrincipalName
                    displayName = $_.displayName
                })
                if ($stale.Count -ge 50) { return }
            }
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1170' -Default 25
$sample = if ($stale.Count -gt 0) {
            ($stale | Select-Object -First 10 | ForEach-Object {
                "| $($_.userPrincipalName) | $($_.displayName) |"
            }) -join "`n"
        } else { '_none — every active non-privileged user has signed in within 90 days._' }

        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Stale non-privileged users (active accounts, no sign-in 90d) | **$($stale.Count)** | $threshold |
| Break-glass accounts excluded (compliant by config) | $excludedBreakGlass | n/a |

### Sample (first 10)

| UPN | Display name |
|---|---|
$sample
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $stale.Count | Should -BeLessThan $threshold
    }
}
