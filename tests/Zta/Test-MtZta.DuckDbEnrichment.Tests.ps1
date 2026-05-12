# ZTA enrichment tests — high-leverage queries against the loaded ZTA bundle.
#
# Phase 4 (2026-05-10): each test reads via `Get-MtZta -Section Reader` which
# returns whichever tier is available — Tier 2 (DuckDB) when the assembly is
# loadable, else Tier 1 (JSON shadow). Both tiers expose the same primitives
# (`GetRows`, `BuildIndex`) so the test logic is tier-agnostic. As a result
# these tests now run universally — no DuckDB binary in `lib/` required.
#
# Graph role template IDs used in this file (canonical, tenant-invariant —
# documented at https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference):
#
#   62e90394-69f5-4237-9190-012177145e10   Global Administrator
#
# References:
#   ZTA project        https://microsoft.github.io/zerotrustassessment/
#   Microsoft Learn    https://learn.microsoft.com/security/zero-trust/assessment/

Describe 'ZTA enrichment — Identity + RoleAssignment cross-checks' -Tag 'ZTA' {

    It 'MT.Zta.1104: Stale-signin user count is below the warn threshold. See https://maester.dev/docs/tests/MT.Zta.1104' -Tag 'MT.Zta.1104','Severity:High','Identity','StaleSignIn' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
Counts users whose **most-recent successful sign-in is older than 90 days** via the ZTA `SignIn` table. Stale users with active accounts are the easiest credential-theft entry point — disabling or removing them is high-leverage. Threshold: warn at 25.

## How to remediate
1. Entra ID → Users → filter by ``signInActivity.lastSignInDateTime < 90 days``.
2. For each: confirm with the user's manager whether the account is still required.
3. Disable (preferred) or delete; for service accounts, rotate to managed identity / service principal with rotation.
'@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'Neither Tier 1 (JSON shadow) nor Tier 2 (DuckDB) is available — bundle may be malformed or missing zt-export/.'
            return
        }

        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1104' -Default 25
        $cutoff = (Get-Date).ToUniversalTime().AddDays(-90)
        try {
            # Stream SignIn rows; collect distinct userIds whose latest createdDateTime is past the cutoff.
            $latestByUser = @{}
            $signInRows = & $reader.GetRows 'SignIn'
            foreach ($r in $signInRows) {
                if (-not $r.userId) { continue }
                if (-not $r.createdDateTime) { continue }
                $dt = $null
                try { $dt = [datetime]::Parse([string]$r.createdDateTime).ToUniversalTime() } catch { continue }
                if (-not $latestByUser.ContainsKey($r.userId) -or $dt -gt $latestByUser[$r.userId]) {
                    $latestByUser[$r.userId] = $dt
                }
            }
            $count = ($latestByUser.GetEnumerator() | Where-Object { $_.Value -lt $cutoff }).Count
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Distinct users whose latest sign-in is > 90 days old | **$count** | $threshold |

Logic: stream SignIn rows, track latest ``createdDateTime`` per ``userId``, count those past the 90-day cutoff.
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $count | Should -BeLessThan $threshold
    }

    It 'MT.Zta.1107: No permanent non-break-glass Global Administrator role assignments. See https://maester.dev/docs/tests/MT.Zta.1107' -Tag 'MT.Zta.1107','Severity:Critical','PIM','PrivilegedAccess' {
        $zta = Get-MtZta

        # Global Administrator role definition ID — well-known, tenant-invariant.
        $globalAdminRoleId = '62e90394-69f5-4237-9190-012177145e10'

        $description = @"
## What this test checks
Lists **all** permanent (non-PIM-eligible) Global Administrator role assignments via the ZTA ``RoleAssignment`` table. Each assignment is annotated as either:

- ``✓ break-glass`` — declared in ``maester-config.json`` ``GlobalSettings.EmergencyAccessAccounts``. Permanent grant is **expected** for these (compliant by config).
- ``❌ permanent grant`` — non-break-glass account with a permanent grant. **Critical finding** — convert to PIM-eligible.

The assertion fails only when there is at least one ``❌`` row.

## How to declare break-glass accounts
Add the account to ``maester-config.json`` under ``GlobalSettings.EmergencyAccessAccounts``. Three accepted shapes:

```json
"GlobalSettings": {
  "EmergencyAccessAccounts": [
    "breakglass1@contoso.onmicrosoft.com",
    "12345678-1234-1234-1234-123456789012",
    { "userPrincipalName": "breakglass2@contoso.onmicrosoft.com", "displayName": "Tier-0 emergency #2" }
  ]
}
```

## How to remediate ❌ rows
1. Entra ID → Roles & administrators → Global administrator → list current assignments.
2. For each non-break-glass row: convert to PIM-eligible (Eligible assignments tab) and remove the permanent grant.

## Related Maester core tests (read together)
This test answers a question the policy-state family does NOT: *"is the grant standing, or just-in-time?"*. Run alongside:

- ``MT.1032`` — *Limited number of Global Admins are assigned* (Maester core). Caps the COUNT but does not distinguish permanent vs PIM-eligible.
- ``CIS.M365.1.1.3`` — *Between two and four global admins are designated*. Same: count-only.
- ``CISA.MS.AAD.7.1`` — *A minimum of two and a maximum of eight users SHALL be provisioned with Global Administrator*. Count-only.
- ``CISA.MS.AAD.7.6`` — *Activation of the Global Administrator role SHALL require approval*. Policy-side; does not check whether anyone bypasses activation via a standing grant.
- ``CISA.MS.AAD.7.7`` — *Eligible and Active highly privileged role assignments SHALL be monitored*. Closest in spirit; ``MT.Zta.1107`` provides the specific assertion ("zero permanent grants except break-glass").

**Joint reading**: passing ``MT.1032`` / ``CIS.M365.1.1.3`` with 2 GAs assigned is NOT sufficient if both are permanent grants and neither is declared break-glass. ``MT.Zta.1107`` catches that specific failure mode.
"@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'Neither Tier 1 (JSON shadow) nor Tier 2 (DuckDB) is available — bundle may be malformed.'
            return
        }

        try {
            # Collect all permanent GA assignments + resolve UPN/displayName via User table.
            $assignments = & $reader.GetRows 'RoleAssignment' { param($r) $r.roleDefinitionId -eq $globalAdminRoleId }
            $userIdx = & $reader.BuildIndex 'User' 'id'

            $rows = @($assignments | ForEach-Object {
                $principalId = [string]$_.principalId
                $u = $userIdx[$principalId]
                $upn = if ($u) { $u.userPrincipalName } else { $null }
                $dn  = if ($u) { $u.displayName }       else { '(unresolved — possibly service principal or group)' }
                $isBreakGlass = Test-MtZtaIsEmergencyAccess -Id $principalId -UserPrincipalName $upn
                [pscustomobject]@{
                    PrincipalId = $principalId
                    UPN = if ($upn) { $upn } else { '(no UPN)' }
                    DisplayName = $dn
                    IsBreakGlass = $isBreakGlass
                }
            })
            $nonBreakGlass = @($rows | Where-Object { -not $_.IsBreakGlass })
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $declared = @(Get-MtZta -Section EmergencyAccessAccounts).Count

        # Render ALL assignments — break-glass first, then findings.
        $tableRows = ($rows | Sort-Object IsBreakGlass -Descending | ForEach-Object {
            $status = if ($_.IsBreakGlass) {
                '✓ break-glass (declared in maester-config)'
            } else {
                '❌ permanent grant — convert to PIM-eligible'
            }
            "| $($_.UPN) | $($_.DisplayName) | $status |"
        }) -join "`n"

        $result = @"
| UPN | Display name | Status |
|---|---|---|
$(if ($tableRows) { $tableRows } else { '| _no permanent Global Administrator assignments_ | — | — |' })

| Metric | Value |
|---|---|
| Total permanent GA assignments | $($rows.Count) |
| ✓ break-glass (compliant by config) | $($rows.Count - $nonBreakGlass.Count) |
| ❌ findings (permanent grants requiring conversion) | **$($nonBreakGlass.Count)** |
| Declared break-glass entries in maester-config | $declared |
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $nonBreakGlass.Count | Should -Be 0 -Because (
            "Found $($nonBreakGlass.Count) permanent Global Admin assignment(s) that are NOT declared as break-glass in maester-config.json. " +
            'Either convert them to PIM-eligible OR add them to GlobalSettings.EmergencyAccessAccounts if they are intentional break-glass accounts.'
        )
    }
}
