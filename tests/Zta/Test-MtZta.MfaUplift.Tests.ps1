# MFA uplift gap-fill — when ZTA flags weak/single-factor authentication usage,
# verify whether single-factor / phishable users have a CAPABLE corporate device
# to register a stronger factor (Windows Hello for Business, Authenticator,
# Passkey/FIDO2). Without that link, the recommendation "use phish-resistant MFA"
# is unactionable.
#
# Phase 4 (2026-05-10): tier-agnostic via `Get-MtZta -Section Reader`. Runs on
# Tier 1 (JSON shadow) by default, accelerated by Tier 2 (DuckDB) when the
# assembly is auto-detected. No DuckDB binary required in `lib/`.
#
# ZTA TestId triggers used in this file (canonical names from
# ZeroTrustAssessmentReport.json `Tests[].TestTitle`):
#
#   21782  Identity / Privileged access
#          Privileged accounts have phishing-resistant methods registered
#   21784  Identity / Access control + Credential management
#          All user sign-in activity uses phishing-resistant authentication
#   21801  Identity / Credential management
#          Users have strong authentication methods configured
#   21804  Identity / Credential management
#          SMS and Voice Call authentication methods are disabled
#
# References:
#   ZTA project        https://microsoft.github.io/zerotrustassessment/
#   Microsoft Learn    https://learn.microsoft.com/security/zero-trust/assessment/

Describe 'ZTA MFA uplift readiness' -Tag 'ZTA' {

    It 'MT.Zta.1140: Users without phish-resistant MFA registered. See https://maester.dev/docs/tests/MT.Zta.1140' `
       -Tag 'MT.Zta.1140','Severity:High','Identity','MFA' {

        $description = @'
## What this test checks
Inspects `UserRegistrationDetails.methodsRegistered` and surfaces members who have **zero** phish-resistant methods registered. Phish-resistant methods are tenant-invariant per Microsoft Graph (FIDO2, Windows Hello for Business, X.509 cert with PIN, device-bound passkeys). Anyone without one is in either of two failure modes:

- **No MFA at all** (`methodsRegistered` is empty) — worst case; password is the only factor.
- **Phishable methods only** — the user has SMS / voice / email / Authenticator-push / TOTP (software or hardware) / `microsoftAuthenticatorPasswordless`. All of these can be relayed by an AiTM proxy or, in the passwordless case, collapse to "approve push on the same device that owns the session" under a stolen-device threat model.

The previous "single-factor = methodsRegistered.Count <= 1" heuristic conflated *no MFA* with *single FIDO2 key*, which is the opposite signal. The classification used here comes from `Get-MtZtaAuthMethodSet`, which is the single source of truth across MT.Zta.1140 / 1141 / 1142 / 1143.

Gap-fill triggered by ZTA [`21801`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21801.md) (strong auth methods configured) or [`21784`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21784.md) (phish-resistant auth) when Failed.

## How to remediate
1. Entra ID → Security → Authentication methods → Registration campaign — push a phish-resistant registration nudge.
2. Conditional Access → enforce **Phishing-resistant MFA** authentication strength on privileged users first, then broaden.
3. Track week-over-week reduction in the `No MFA` and `Phishable-only` rows.

## Related Maester core tests (read together)
This test inspects **user-registration state** (have users actually registered phish-resistant methods?). The Maester core family inspects **policy state** (does the tenant configuration allow / enforce / disable specific methods?). Both layers must align for end-to-end protection.

Policy-state counterparts:

- `CISA.MS.AAD.3.1` / `CISA.MS.AAD.3.2` — *Phishing-resistant MFA SHALL be enforced for all users* (and the alternative-auth-strength fallback). Verifies a CA policy exists requiring phish-resistant MFA.
- `EIDSCA.AF01` — FIDO2 security key — State (enabled at tenant level).
- `EIDSCA.AF02` / `AF03` / `AF04` / `AF05` — FIDO2 self-service / attestation / key restriction / disallow restricted keys.
- `CISA.MS.AAD.3.5` — *Authentication methods SMS, Voice Call, and Email OTP SHALL be disabled*.
- `EIDSCA.AS04` — SMS for sign-in.
- `EIDSCA.AV01` — Voice call state.
- `MT.1063` — *App registration owners should have MFA registered* (overlapping intent, narrower scope: owners only).

**Joint reading**:

- ``CISA.MS.AAD.3.1`` Passed + ``MT.Zta.1140`` Failed → policy enforces phish-resistant, but users haven't migrated. At sign-in time the unprepared users will be hard-blocked or fall back via legacy escape paths. **Run a registration campaign — don't celebrate yet.**
- ``CISA.MS.AAD.3.1`` Failed + ``MT.Zta.1140`` Passed → users have phish-resistant methods registered, but the CA policy doesn't enforce. Attackers can social-engineer users back to a phishable method. **Add the CA policy now.**
- Both Passed → end-to-end phish-resistant for the population covered. ✅
- Both Failed → no policy AND no registrations. Highest-impact gap.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('21801','21784') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag the trigger condition (21801/21784 not Failed) — gap-fill not applicable."
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            # Build sync-account principal-id set (Directory Sync role + Sync_* fallback).
            $syncRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
            $syncPrincipalIds = @{}
            try {
                $raSync = & $reader.GetRows 'RoleAssignment' { param($r) $r.roleDefinitionId -eq $syncRoleTemplateId }
                foreach ($r in @($raSync)) { if ($r.principalId) { $syncPrincipalIds[[string]$r.principalId] = $true } }
            } catch { }

            # Build a disabled-user id set so we can exclude `accountEnabled=false`
            # users from the flagged total. `UserRegistrationDetails` does not
            # carry `accountEnabled`; the `User` table does. License / sign-in-
            # frequency is intentionally NOT used as the filter — disabled is
            # the only definitive "this is not a real user" signal (per operator
            # decision 2026-05-11): shared mailboxes / functional accounts may
            # legitimately not have a license, may rarely sign in, but still
            # require MFA when they DO authenticate.
            $disabledUserIds = @{}
            try {
                $disabledUsers = & $reader.GetRows 'User' { param($u) $u.accountEnabled -eq $false }
                foreach ($u in @($disabledUsers)) {
                    if ($u.id) { $disabledUserIds[[string]$u.id] = $true }
                }
            } catch { }

            $methodSet = Get-MtZtaAuthMethodSet
            $phishResistant = $methodSet.PhishResistant

            # Stream candidates: any member without at least one phish-resistant method.
            $candidates = & $reader.GetRows 'UserRegistrationDetails' {
                param($u)
                if ($u.userType -ne 'member') { return $false }
                $methods = if ($u.methodsRegistered) { @($u.methodsRegistered) } else { @() }
                # Use the upvalue from enclosing scope.
                @($methods | Where-Object { $_ -in $phishResistant }).Count -eq 0
            }

            $excludedBreakGlass = 0
            $excludedSync = 0
            $excludedDisabled = 0
            $noMfa = New-Object System.Collections.Generic.List[object]
            $weakOnly = New-Object System.Collections.Generic.List[object]
            foreach ($u in @($candidates)) {
                if ($u.id -and $disabledUserIds.ContainsKey([string]$u.id)) { $excludedDisabled++; continue }
                if ($u.id -and $syncPrincipalIds.ContainsKey([string]$u.id)) { $excludedSync++; continue }
                if ($u.userPrincipalName -and $u.userPrincipalName -match '^Sync_') { $excludedSync++; continue }
                if (Test-MtZtaIsEmergencyAccess -Id $u.id -UserPrincipalName $u.userPrincipalName) { $excludedBreakGlass++; continue }
                $methods = if ($u.methodsRegistered) { @($u.methodsRegistered) } else { @() }
                if ($methods.Count -eq 0) { $noMfa.Add($u) } else { $weakOnly.Add($u) }
            }
            $totalFlagged = $noMfa.Count + $weakOnly.Count
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        # Sub-thresholds (introduced 2026-05-11): the two failure modes have very
        # different remediation cost and risk profile, so they get separate
        # operator-tunable budgets rather than one combined total:
        #
        #   MT.Zta.1140.NoMfa      "no MFA at all"  — default 0 (zero tolerance —
        #                          a password-only account is the highest-impact
        #                          uplift opportunity and should never sit in
        #                          warn-band).
        #   MT.Zta.1140.Phishable  "phishable methods only" — default 5 (small
        #                          warn-band because Authenticator-push + SMS
        #                          users still have *some* compensation; bulk
        #                          uplift is acceptable as long as the count is
        #                          actively trending down).
        #
        # The legacy `MT.Zta.1140` key (total) is kept as a third assertion so
        # existing maester-config files still gate. Operators wanting a single
        # rolling number can keep using that key; tenants wanting sharper
        # control set the sub-thresholds and remove the total.
        $noMfaMax     = [int](Get-MtZtaThreshold -TestId 'MT.Zta.1140.NoMfa'     -Default 0)
        $phishableMax = [int](Get-MtZtaThreshold -TestId 'MT.Zta.1140.Phishable' -Default 5)
        $totalMax     = [int](Get-MtZtaThreshold -TestId 'MT.Zta.1140'           -Default ($noMfaMax + $phishableMax + 5))

        $renderRows = {
            param($rows, $tag)
            if ($rows.Count -eq 0) { return $null }
            ($rows | Select-Object -First 10 | ForEach-Object {
                $upn = if ($_.userPrincipalName) { $_.userPrincipalName } else { '(no UPN)' }
                $methods = if ($_.methodsRegistered) { (@($_.methodsRegistered) -join ', ') } else { '(none)' }
                "| $tag | $upn | $methods |"
            }) -join "`n"
        }
        $sampleRows = @()
        $r = & $renderRows $noMfa 'No MFA'         ; if ($r) { $sampleRows += $r }
        $r = & $renderRows $weakOnly 'Phishable-only' ; if ($r) { $sampleRows += $r }
        $sample = if ($sampleRows) { ($sampleRows -join "`n") } else { '_no flagged members — every active member has at least one phish-resistant method registered._' }

        $noMfaStatus     = if ($noMfa.Count     -le $noMfaMax)     { 'within' } else { 'over' }
        $phishableStatus = if ($weakOnly.Count  -le $phishableMax) { 'within' } else { 'over' }
        $totalStatus     = if ($totalFlagged    -le $totalMax)     { 'within' } else { 'over' }

        $result = @"
| Metric | Value | Threshold | Status |
|---|---|---|---|
| Members with **no MFA** registered | **$($noMfa.Count)** | $noMfaMax | $noMfaStatus |
| Members with **phishable-only** methods | **$($weakOnly.Count)** | $phishableMax | $phishableStatus |
| **Total flagged (no MFA + phishable-only)** | **$totalFlagged** | $totalMax | $totalStatus |
| Disabled accounts excluded | $excludedDisabled | — | — |
| Break-glass accounts excluded | $excludedBreakGlass | — | — |
| Sync accounts excluded | $excludedSync | — | — |
| ZTA trigger tests Failed | $($triggered.Count) | — | — |

Configure thresholds in ``maester-config.json`` → ``ZtaSettings.Thresholds``:

- ``MT.Zta.1140.NoMfa`` (default 0) — members with NO MFA registered
- ``MT.Zta.1140.Phishable`` (default 5) — members with only phishable methods
- ``MT.Zta.1140`` (default $($noMfaMax + $phishableMax + 5)) — combined total (legacy)

### Sample (first 10 per bucket)

| Bucket | UPN | methodsRegistered |
|---|---|---|
$sample
"@

        Add-MtTestResultDetail -Description $description -Result $result

        # All three must hold. Listing them on separate lines keeps the failure
        # message specific so the operator can tell WHICH budget was breached.
        $noMfa.Count    | Should -BeLessOrEqual $noMfaMax     -Because "members with no MFA must stay within MT.Zta.1140.NoMfa (limit: $noMfaMax)"
        $weakOnly.Count | Should -BeLessOrEqual $phishableMax -Because "members with phishable-only methods must stay within MT.Zta.1140.Phishable (limit: $phishableMax)"
        $totalFlagged   | Should -BeLessOrEqual $totalMax     -Because "combined flagged total must stay within MT.Zta.1140 (limit: $totalMax)"
    }

    It 'MT.Zta.1141: WHfB uplift candidates — users without phish-resistant MFA who already have a corporate device. See https://maester.dev/docs/tests/MT.Zta.1141' `
       -Tag 'MT.Zta.1141','Severity:Medium','Identity','MFA','Uplift' {

        $description = @'
## What this test checks
Cross-references `UserRegistrationDetails` (members without any phish-resistant method registered) with `Device` (`trustType` in `AzureAd` / `ServerAd` / `Workplace`). Surfaces users who **could be moved to Windows Hello for Business** because they already have a corporate-trusted device — the highest-leverage MFA uplift path with no procurement and no shipping new tokens.

The phish-resistant classification comes from `Get-MtZtaAuthMethodSet -Bucket PhishResistant` (FIDO2, WHfB, X.509-with-PIN, device-bound passkeys).

The `Device.trustType` enum is the Graph-canonical set: `AzureAd` = Entra-joined, `ServerAd` = hybrid (on-prem AD + Entra), `Workplace` = workplace-joined for SSO. Hybrid-joined devices do NOT emit a free-text `"Hybrid Azure AD joined"` value — that's a portal display string. ZTA emits the raw enum.

## How to remediate
1. For each candidate: open Entra ID → User → Authentication methods → register Windows Hello for Business.
2. Optionally, apply a registration-campaign authentication-strength policy targeted at this group.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('21801','21784') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 21801/21784 — gap-fill not applicable."
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            # Build sync-account principal-id set (Directory Sync role + Sync_* fallback).
            $syncRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
            $syncPrincipalIds = @{}
            try {
                $raSync = & $reader.GetRows 'RoleAssignment' { param($r) $r.roleDefinitionId -eq $syncRoleTemplateId }
                foreach ($r in @($raSync)) { if ($r.principalId) { $syncPrincipalIds[[string]$r.principalId] = $true } }
            } catch { }

            # Build user-id -> "no phish-resistant" flag index, excluding break-glass + sync.
            # (Break-glass accounts shouldn't appear on the uplift list — they're
            # intentionally configured with their target factor already. Sync accounts
            # use cert-based auth and aren't candidates for interactive WHfB rollout.)
            $phishResistant = (Get-MtZtaAuthMethodSet).PhishResistant
            $weakUserIds = @{}
            $userRegRows = & $reader.GetRows 'UserRegistrationDetails' {
                param($u)
                if ($u.userType -ne 'member') { return $false }
                $methods = if ($u.methodsRegistered) { @($u.methodsRegistered) } else { @() }
                @($methods | Where-Object { $_ -in $phishResistant }).Count -eq 0
            }
            foreach ($u in $userRegRows) {
                if (-not $u.id) { continue }
                if ($syncPrincipalIds.ContainsKey([string]$u.id)) { continue }
                if ($u.userPrincipalName -and $u.userPrincipalName -match '^Sync_') { continue }
                if (Test-MtZtaIsEmergencyAccess -Id $u.id -UserPrincipalName $u.userPrincipalName) { continue }
                $weakUserIds[[string]$u.id] = $u
            }

            # Stream Device rows; surface the user if device is corporate-trusted AND
            # user lacks phish-resistant MFA. Trust-type values are the canonical
            # Microsoft Graph enum: AzureAd (Entra-joined), ServerAd (hybrid-joined),
            # Workplace (registered for SSO). Hybrid-joined devices emit `ServerAd`,
            # NOT a free-text "Hybrid Azure AD joined" label.
            $managedTrustTypes = @('AzureAd','Workplace','ServerAd')
            $candidates = New-Object System.Collections.Generic.List[object]
            $seen = @{}
            $deviceRows = & $reader.GetRows 'Device' {
                param($d)
                ($d.trustType -in $managedTrustTypes) -and $d.userId -and $weakUserIds.ContainsKey([string]$d.userId)
            }
            foreach ($d in $deviceRows) {
                $uid = [string]$d.userId
                if ($seen.ContainsKey($uid)) { continue }
                $seen[$uid] = $true
                $u = $weakUserIds[$uid]
                $candidates.Add([pscustomobject]@{
                    id = $u.id
                    userPrincipalName = $u.userPrincipalName
                })
                if ($candidates.Count -ge 50) { break }
            }
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        # Threshold semantics: "must have AT LEAST <threshold> uplift candidates";
        # below that we treat as "no easy uplift path" and SKIP with reason rather
        # than fail. Skipping is more honest than a Failed row with "0 candidates"
        # because the framework can't tell the operator anything new — it's a
        # deliberate "needs strategic intervention, not test failure" signal.
        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1141' -Default 1
        if ($candidates.Count -lt $threshold) {
            Add-MtTestResultDetail `
                -Description $description `
                -SkippedBecause Custom `
                -SkippedCustomReason ("ZTA flagged single-factor users ($($triggered.Count) trigger test(s) Failed) but only $($candidates.Count) uplift candidate(s) found " +
                    "(threshold: at least $threshold). WHfB rollout requires capable corporate devices first — provision Windows / Entra-joined " +
                    "devices for these users before this gap can be closed by MFA registration alone. " +
                    "**This is wanted behaviour**: skipping signals 'needs strategic intervention, not test failure'.")
            return
        }

        $sample = ($candidates | Select-Object -First 10 | ForEach-Object {
            "| $($_.userPrincipalName) | $($_.id) |"
        }) -join "`n"

        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Uplift candidates (single-factor + corporate device) | **$($candidates.Count)** | at least $threshold |
| ZTA trigger tests | $($triggered.Count) Failed | — |

### Sample (first 10)

| UPN | UserId |
|---|---|
$sample
"@

        Add-MtTestResultDetail -Description $description -Result $result
        # We have at least `threshold` candidates; this test passes — operators
        # have an actionable list. The Failed counterpart in earlier versions
        # ("0 candidates = Failed") was confusing; replaced with explicit Skip.
        $candidates.Count | Should -BeGreaterOrEqual $threshold
    }

    It 'MT.Zta.1142: Phishable-method users with mobile device registered. See https://maester.dev/docs/tests/MT.Zta.1142' `
       -Tag 'MT.Zta.1142','Severity:Medium','Identity','MFA','Phishable' {

        $description = @'
## What this test checks
Cross-references users registered with phishable methods (SMS / voice / email-OTP / TOTP / Authenticator-push) against `Device` rows for iOS / Android. These users CAN be moved to Passkey or Windows Hello for Business — both phish-resistant — using a device they already have.

The phishable set comes from `Get-MtZtaAuthMethodSet -Bucket Phishable` (single source of truth across MT.Zta.1140 / 1142 / 1143). Exact array membership rather than substring regex — Graph emits these as a closed enum, so a substring match like `email` would falsely catch any future enum value containing the word "email".

The mobile-OS check uses the actual `Device.operatingSystem` values ZTA emits: `iOS`, `IPad` (capital-I capital-P — that's the literal column value, not "iPadOS"), and `Android`.

Break-glass and Entra Connect sync accounts are excluded — they do not appear on the typical-user uplift list.

## How to remediate
1. Push Authenticator app via Intune to the listed devices.
2. Authentication-methods policy → require Passkey or Authenticator with phishing-resistant requirement.
3. Block phishable methods (SMS / voice / TOTP / Authenticator-push) once registration completes.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('21804','21784') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 21804/21784 — gap-fill not applicable."
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            # Build sync-account principal-id set (Directory Sync role + Sync_* fallback).
            $syncRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
            $syncPrincipalIds = @{}
            try {
                $raSync = & $reader.GetRows 'RoleAssignment' { param($r) $r.roleDefinitionId -eq $syncRoleTemplateId }
                foreach ($r in @($raSync)) { if ($r.principalId) { $syncPrincipalIds[[string]$r.principalId] = $true } }
            } catch { }

            $phishable = (Get-MtZtaAuthMethodSet).Phishable
            $phishableIds = @{}
            $userRegRows = & $reader.GetRows 'UserRegistrationDetails' {
                param($u)
                if ($u.userType -ne 'member') { return $false }
                $methods = if ($u.methodsRegistered) { @($u.methodsRegistered) } else { @() }
                @($methods | Where-Object { $_ -in $phishable }).Count -gt 0
            }
            foreach ($u in $userRegRows) {
                if (-not $u.id) { continue }
                if ($syncPrincipalIds.ContainsKey([string]$u.id)) { continue }
                if ($u.userPrincipalName -and $u.userPrincipalName -match '^Sync_') { continue }
                if (Test-MtZtaIsEmergencyAccess -Id $u.id -UserPrincipalName $u.userPrincipalName) { continue }
                $phishableIds[[string]$u.id] = $u
            }

            # Mobile OS values per actual ZTA emission: 'iOS', 'IPad', 'Android'.
            # 'iPadOS' is portal-display; the column carries the legacy 'IPad' string.
            $mobileOs = @('iOS','IPad','Android')
            $candidates = New-Object System.Collections.Generic.List[object]
            $seen = @{}
            $deviceRows = & $reader.GetRows 'Device' {
                param($d)
                ($d.operatingSystem -in $mobileOs) -and $d.userId -and $phishableIds.ContainsKey([string]$d.userId)
            }
            foreach ($d in $deviceRows) {
                $uid = [string]$d.userId
                if ($seen.ContainsKey($uid)) { continue }
                $seen[$uid] = $true
                $u = $phishableIds[$uid]
                $candidates.Add([pscustomobject]@{
                    id = $u.id
                    userPrincipalName = $u.userPrincipalName
                })
                if ($candidates.Count -ge 50) { break }
            }
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        # Same semantics as MT.Zta.1141: "must have at least <threshold> candidates";
        # below that we Skip with a deliberate reason, not Fail. See 1141 for rationale.
        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1142' -Default 1
        if ($candidates.Count -lt $threshold) {
            Add-MtTestResultDetail `
                -Description $description `
                -SkippedBecause Custom `
                -SkippedCustomReason ("ZTA flagged phishable-method users ($($triggered.Count) trigger test(s) Failed) but only $($candidates.Count) " +
                    "user(s) with a mobile device found (threshold: at least $threshold). Authenticator-app rollout requires " +
                    "mobile-device enrolment first — provision iOS/Android devices and enrol via Intune before phishable-method " +
                    "migration can complete via this path. **This is wanted behaviour**: the skip signals 'needs strategic " +
                    "intervention, not test failure'.")
            return
        }

        $sample = ($candidates | Select-Object -First 10 | ForEach-Object {
            "| $($_.userPrincipalName) | $($_.id) |"
        }) -join "`n"

        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Phishable-method users with mobile device | **$($candidates.Count)** | at least $threshold |
| ZTA trigger tests | $($triggered.Count) Failed | — |

### Sample (first 10)

| UPN | UserId |
|---|---|
$sample
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $candidates.Count | Should -BeGreaterOrEqual $threshold
    }

    It 'MT.Zta.1143: Privileged accounts on phishable methods (Critical gap). See https://maester.dev/docs/tests/MT.Zta.1143' `
       -Tag 'MT.Zta.1143','Severity:Critical','Identity','MFA','Privileged','Phishable' {

        $description = @'
## What this test checks
**Critical gap.** Joins `UserRegistrationDetails` (users with phishable methods) with `RoleAssignment` (any directory role) to find privileged users who could be phished. Privileged accounts on SMS / voice / email-OTP / TOTP / Authenticator-push MUST be uplifted to phish-resistant MFA before any other remediation work.

The phishable set comes from `Get-MtZtaAuthMethodSet -Bucket Phishable` (single source of truth shared with MT.Zta.1140 / 1142). Exact array membership against the closed Graph enum.

### Why a privileged user with BOTH strong AND weak methods still flags

The assertion fires whenever a privileged account has **any** phishable method *registered* — even if WHfB / FIDO2 / Passkey are also registered on the same account. This is intentional. A registered phishable method is an authentication PATH the attacker can drive the user toward (via AiTM phishing, fatigue push, SIM-swap on `mobilePhone`, SMTP-relay on `email`). Strong methods don't neutralise weak ones unless **Conditional Access enforces an authentication strength that excludes them at sign-in time**.

So this test surfaces the method *inventory* risk: "what methods CAN this admin use to sign in?" The compensating CA check lives in [`MT.Zta.1131`](https://maester.dev/docs/tests/MT.Zta.1131) (What-If returns a phish-resistant `authenticationStrength` for privileged users).

Break-glass accounts (declared in `GlobalSettings.EmergencyAccessAccounts`) and Entra Connect sync accounts (members of the Directory Synchronization Accounts role) are excluded — break-glass is covered by a dedicated CA + auth-strength path, sync uses cert-based auth and doesn't register interactive MFA methods.

## How to remediate
**Treat as an incident** when 1143 + 1131 both Failed. When only 1143 Failed, treat as a defence-in-depth gap. For each user listed:
1. Block phishable methods on this account immediately via authentication-methods policy.
2. Force re-registration with FIDO2 / Passkey / Windows Hello for Business.
3. If MFA registration cannot complete in <24h: temporarily remove privileged role until re-registration is verified.
4. Verify CA `authenticationStrength` enforces phish-resistant for the role — see MT.Zta.1131.

## Related Maester core tests (read together)
This test inspects **registration inventory** (what phishable methods are registered on a priv account). It must be read alongside the policy-state and live-enforcement counterparts to avoid mis-triaging.

- ``CISA.MS.AAD.3.6`` — *Phishing-resistant MFA SHALL be required for highly privileged roles* (policy state).
- ``MT.Zta.1131`` — CA What-If for a sample priv user (live enforcement).
- ``MT.Zta.1140`` — All members without phish-resistant MFA registered (registration inventory, all-user scope; 1143 is the priv-user subset with the Critical severity overlay).

**Joint reading (1143 + 1131)**:

- **1143 Failed + 1131 Passed** → inventory is risky but live sign-in is gated. An authentication-methods policy change or CA misconfiguration could expose the weak path. **Defence-in-depth gap — reduce the inventory.**
- **1143 Failed + 1131 Failed** → both the inventory AND the live enforcement are weak. **Treat as an incident** — the priv user can sign in with a phishable method right now.
- **1143 Passed + 1131 Passed** → both clean. ✅
- **1143 Passed + 1131 Failed** → unusual; investigate the CA scope (the auth-strength policy may target an OU/role that excludes the admin in question).

**Three-way reading (1143 + 1131 + CISA.MS.AAD.3.6)**:

- All three Passed → end-to-end phish-resistant for priv. ✅
- ``CISA.MS.AAD.3.6`` Passed + 1131 Failed → policy exists but doesn't actually scope this priv user. CA exclusions or group-target mistake.
- ``CISA.MS.AAD.3.6`` Failed + 1131 Passed → no named CISA policy but some other CA happens to enforce. Add the named policy explicitly.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('21782','21804') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 21782 (privileged accounts have phish-resistant methods registered) or 21804 (SMS+Voice disabled) — both are Passed in this run, so privileged-on-phishable check is N/A. **This is wanted behaviour**: the tenant is healthy in this area; the gap-fill only fires when ZTA detects the underlying weakness."
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            # Build a set of all principalIds with at least one role assignment.
            $privilegedIds = @{}
            $raRows = & $reader.GetRows 'RoleAssignment'
            foreach ($r in $raRows) {
                if ($r.principalId) { $privilegedIds[[string]$r.principalId] = $true }
            }

            # Build sync-account principal-id set (Directory Sync role + Sync_* fallback).
            # Sync accounts are technically privileged (they hold the sync role) but
            # they don't authenticate interactively, so they shouldn't appear on the
            # phishable-priv list.
            $syncRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
            $syncPrincipalIds = @{}
            try {
                $raSync = & $reader.GetRows 'RoleAssignment' { param($r) $r.roleDefinitionId -eq $syncRoleTemplateId }
                foreach ($r in @($raSync)) { if ($r.principalId) { $syncPrincipalIds[[string]$r.principalId] = $true } }
            } catch { }

            $phishable = (Get-MtZtaAuthMethodSet).Phishable
            $hits = New-Object System.Collections.Generic.List[object]
            $excludedBreakGlass = 0
            $excludedSync = 0
            $userRegRows = & $reader.GetRows 'UserRegistrationDetails' {
                param($u)
                if ($u.userType -ne 'member') { return $false }
                if (-not $u.id -or -not $privilegedIds.ContainsKey([string]$u.id)) { return $false }
                $methods = if ($u.methodsRegistered) { @($u.methodsRegistered) } else { @() }
                @($methods | Where-Object { $_ -in $phishable }).Count -gt 0
            }
            foreach ($u in $userRegRows) {
                if ($syncPrincipalIds.ContainsKey([string]$u.id)) { $excludedSync++; continue }
                if ($u.userPrincipalName -and $u.userPrincipalName -match '^Sync_') { $excludedSync++; continue }
                if (Test-MtZtaIsEmergencyAccess -Id $u.id -UserPrincipalName $u.userPrincipalName) { $excludedBreakGlass++; continue }
                $hits.Add([pscustomobject]@{
                    id = $u.id
                    userPrincipalName = $u.userPrincipalName
                    methods = if ($u.methodsRegistered) { (@($u.methodsRegistered) -join ', ') } else { '(none)' }
                })
                if ($hits.Count -ge 50) { break }
            }
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $sample = if ($hits.Count -gt 0) {
            ($hits | Select-Object -First 10 | ForEach-Object {
                "| **$($_.userPrincipalName)** | $($_.methods) |"
            }) -join "`n"
        } else { '_none — no privileged user has a phishable method registered._' }

        $result = @"
| Metric | Value |
|---|---|
| Privileged users on phishable methods | **$($hits.Count)** |
| Break-glass accounts excluded | $excludedBreakGlass |
| Sync accounts excluded | $excludedSync |

### Affected accounts (sample of 10)

| UPN | methodsRegistered |
|---|---|
$sample
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $hits.Count | Should -Be 0
    }
}
