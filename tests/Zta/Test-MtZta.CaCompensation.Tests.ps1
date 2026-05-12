# Conditional Access compensation gap-fill — when ZTA flags weak/missing
# authentication enforcement, simulate sign-in scenarios via
# Test-MtConditionalAccessWhatIf (BETA Graph API) to verify the actual policy
# graph blocks/MFAs the right way for representative users.
#
# Why What-If vs reading policy state:
#   Reading static CA policies misses how multiple policies COMPOSE. A tenant
#   may have 30 CA policies; the operator's intent might be MFA-on-everything
#   but a single accidental excludeUsers in one policy can defeat that.
#   What-If asks the policy graph "what would actually happen?" — the answer
#   is the same answer the user gets at sign-in time.
#
# Tag `Beta` is on every test so an upstream API change can be filtered out
# of a run with -ExcludeTag Beta without breaking the build.
#
# ZTA TestId triggers used in this file:
#
#   21782  Identity / Privileged access
#          Privileged accounts have phishing-resistant methods registered
#   21783  Identity / Access control
#          Privileged Microsoft Entra built-in roles are targeted with
#          Conditional Access requiring phishing-resistant authentication
#   21784  Identity / Access control + Credential management
#          All user sign-in activity uses phishing-resistant authentication
#   21801  Identity / Credential management
#          Users have strong authentication methods configured
#
# References:
#   ZTA project        https://microsoft.github.io/zerotrustassessment/
#   Microsoft Learn    https://learn.microsoft.com/security/zero-trust/assessment/
#   Auth-strength API  https://learn.microsoft.com/graph/api/resources/authenticationstrengthpolicy

Describe 'ZTA CA What-If compensation' -Tag 'ZTA' {

    It 'MT.Zta.1130: CA What-If: a normal user signing in to Office 365 is required to MFA. See https://maester.dev/docs/tests/MT.Zta.1130' `
       -Tag 'MT.Zta.1130','Severity:High','ConditionalAccess','WhatIf','Beta','MFA' {

        $description = @'
## What this test checks
Triggered when ZTA [`21784`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21784.md) (phish-resistant auth) or [`21801`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21801.md) (strong auth methods configured) Failed. Picks a sample non-privileged Member user and runs `Test-MtConditionalAccessWhatIf` simulating an Office 365 sign-in from a browser. Asserts the returned grant requires MFA — either via `builtInControls -contains 'mfa'` OR via an `authenticationStrength` reference.

This is the rigorous check for "do we actually require MFA on a normal sign-in?" — independent of how many CA policies exist or how their exclusions compose.

**Sample selection** — break-glass accounts (per `GlobalSettings.EmergencyAccessAccounts`) and Entra Connect sync accounts (`Sync_*` UPN, members of "Directory Synchronization Accounts" / "On Premises Directory Sync Account" role) are excluded from the typical-user sample pool. Sync accounts intentionally bypass interactive MFA and are protected via a dedicated CA blocking sign-in from outside trusted named locations — that hardening is out of scope for "typical user MFA".

## How to remediate
1. Conditional Access → New policy → target All users (exclude break-glass) → All cloud apps → Grant: Require MFA OR Require authentication strength.
2. Save as Report-only first; verify via this same What-If; then Enable.
3. Re-run; the simulation should return mfa or authenticationStrength.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('21784','21801') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 21784/21801 — MFA What-If gap-fill not applicable."
            return
        }

        # Build sync-account principal-id set from RoleAssignment ⨝ "Directory
        # Synchronization Accounts" role (template ID d29b2b05-...). UPN regex
        # ^Sync_ kept as a belt-and-suspenders fallback for cases where the
        # RoleAssignment table isn't fully populated (e.g. last-good fallback bundle).
        $syncRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
        $syncPrincipalIds = @{}
        $reader = Get-MtZta -Section Reader
        if ($reader) {
            try {
                $raSync = & $reader.GetRows 'RoleAssignment' { param($r) $r.roleDefinitionId -eq $syncRoleTemplateId }
                foreach ($r in @($raSync)) { if ($r.principalId) { $syncPrincipalIds[[string]$r.principalId] = $true } }
            } catch { }
        }

        # Pick a sample non-privileged Member. Skip break-glass and sync accounts —
        # both intentionally bypass typical-user CA enforcement and would invert the
        # signal of this test.
        $isExcludedSample = {
            param($u)
            if (-not $u) { return $true }
            if ($u.id -and $syncPrincipalIds.ContainsKey([string]$u.id)) { return $true }
            if ($u.userPrincipalName -and $u.userPrincipalName -match '^Sync_') { return $true }
            return [bool](Test-MtZtaIsEmergencyAccess -Id $u.id -UserPrincipalName $u.userPrincipalName)
        }
        $sampleUser = $null
        if ($zta.Database -and $zta.Database.Query) {
            try {
                $candidates = & $zta.Database.Query "SELECT id, userPrincipalName FROM `"User`" WHERE userType = 'member' AND accountEnabled = true AND id NOT IN (SELECT principalId FROM RoleAssignment) LIMIT 20"
                foreach ($c in @($candidates)) {
                    if (-not (& $isExcludedSample $c)) { $sampleUser = $c; break }
                }
            } catch { }
        }
        if (-not $sampleUser) {
            try {
                $rows = Invoke-MtGraphRequest -RelativeUri 'users?$filter=accountEnabled eq true and userType eq ''Member''&$top=20&$select=id,userPrincipalName' -ApiVersion beta
                foreach ($c in @($rows)) {
                    if (-not (& $isExcludedSample $c)) { $sampleUser = $c; break }
                }
            } catch {
                Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
                return
            }
        }
        if (-not $sampleUser -or -not $sampleUser.id) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No eligible non-privileged Member user found (after excluding break-glass and Sync_* accounts).'
            return
        }

        $office365AppId = 'd3590ed6-52b3-4102-aeff-aad2292ab01c'

        try {
            $whatIf = Test-MtConditionalAccessWhatIf -UserId $sampleUser.id `
                                                     -IncludeApplications $office365AppId `
                                                     -ClientAppType 'browser' `
                                                     -DevicePlatform 'Windows'
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $controls = @($whatIf.grantControls.builtInControls)
        $hasAuthStrength = [bool]$whatIf.grantControls.authenticationStrength
        $mfaRequired = ($controls -contains 'mfa') -or $hasAuthStrength

        $matchedPolicies = if ($whatIf.policies) {
            ($whatIf.policies | Select-Object -First 5 | ForEach-Object { "- $($_.displayName)" }) -join "`n"
        } else { '_no CA policies in scope for this scenario._' }

        $result = @"
| Field | Value |
|---|---|
| Sample user | ``$($sampleUser.userPrincipalName)`` |
| Simulated app | Office 365 |
| Client | browser / Windows |
| Returned builtInControls | $(($controls | Sort-Object -Unique) -join ', ') |
| authenticationStrength present? | $hasAuthStrength |
| **MFA required?** | **$mfaRequired** |

### Policies in scope (first 5)

$matchedPolicies
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $mfaRequired | Should -BeTrue
    }

    It 'MT.Zta.1131: CA What-If: a privileged user is required phish-resistant MFA. See https://maester.dev/docs/tests/MT.Zta.1131' `
       -Tag 'MT.Zta.1131','Severity:High','ConditionalAccess','WhatIf','Beta','PIM','PrivilegedAccess' {

        $description = @'
## What this test checks
Triggered when ZTA [`21782`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21782.md) (privileged accounts have phish-resistant methods registered) or [`21783`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21783.md) (privileged role CA enforces phish-resistant) Failed. Picks a sample privileged user (someone with at least one role assignment) and runs What-If for a sign-in to Office 365. The What-If grant must reference an `authenticationStrength` policy whose `allowedCombinations` are ALL within the phish-resistant set: `fido2`, `windowsHelloForBusiness`, `x509CertificateMultiFactor`.

**Why allowedCombinations and not displayName**: matching on the policy's display name is fragile — a custom auth strength named "Phishing-resistant MFA" with weak combinations would pass; localised display names would fail; an internally-named "FIDO2-only" strength would fail. Inspecting the actual permitted combinations is the only correct check. `x509CertificateSingleFactor` is single-factor cert auth and is explicitly **not** in the set (not MFA).

**Sample selection** — break-glass accounts (per `GlobalSettings.EmergencyAccessAccounts`) and Entra Connect sync accounts (members of the "Directory Synchronization Accounts" role, template ID `d29b2b05-8046-44ba-8758-1e26182fcf32`, with `Sync_*` UPN as a fallback heuristic) are excluded from the sample pool. Break-glass should be covered by a dedicated CA policy requiring phish-resistant MFA for that group only (see MT.1005 for break-glass exclusion correctness); sync accounts use cert-based auth + named-location restriction, not interactive MFA.

The What-If approach is critical here: many tenants have a "Require MFA for admins" policy that uses `builtInControls=mfa`, which accepts SMS/voice — i.e. NOT phish-resistant. Reading the static policy says "MFA required"; What-If reveals the strength is wrong.

## How to remediate
1. Conditional Access → New policy → target privileged role membership (or admin-targeted group).
2. Grant: **Require authentication strength** → choose **Phishing-resistant MFA** (or a custom strength whose allowed combinations are all phish-resistant).
3. Re-run this test; the simulation should report `All phish-resistant? True`.

## Related Maester core tests (read together)
This test answers a question the policy-state family does NOT: *"does the actual policy graph enforce phish-resistant MFA for a real privileged user, after all CA policies compose?"*. It uses Graph What-If — the same evaluation Entra runs at sign-in time.

Policy-state counterparts:

- `CISA.MS.AAD.3.6` — *Phishing-resistant MFA SHALL be required for highly privileged roles*. Verifies a CA policy with phish-resistant grant exists; does not verify it applies to every priv user after exclusions / scopes compose.
- `CISA.MS.AAD.7.6` / `CISA.MS.AAD.7.8` — *GA role activation SHALL require approval / auth context*. Activation-side controls; orthogonal to live sign-in strength.

**Joint reading**:

- ``CISA.MS.AAD.3.6`` Passed + ``MT.Zta.1131`` Passed → policy exists AND it actually enforces at sign-in for the sampled priv user. ✅
- ``CISA.MS.AAD.3.6`` Passed + ``MT.Zta.1131`` Failed → there is a policy but the sampled priv user falls outside its scope (excludeUsers, excluded group, role-based-target with the wrong role IDs, etc.). **Audit the CA policy's user scope and exclusions** — the policy looks right on paper but doesn't apply where it should.
- ``CISA.MS.AAD.3.6`` Failed + ``MT.Zta.1131`` Passed → unusual; the named CISA-flavored policy isn't present, but some OTHER policy in scope happens to require phish-resistant for this user. Solid by luck, fragile by design.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $triggered = @($zta.Tests | Where-Object { $_.TestStatus -eq 'Failed' -and $_.TestId -in @('21782','21783') })
        if ($triggered.Count -eq 0) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "ZTA didn't flag 21782/21783 — privileged-MFA gap-fill not applicable."
            return
        }

        # Build sync-account principal-id set from RoleAssignment ⨝ Directory Sync
        # role (template ID d29b2b05-...). Sync accounts have a directory role
        # so they show up as "privileged" via simple anti-join, but they're not
        # interactive admins; use cert-based auth + named-location restriction.
        $syncRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
        $syncPrincipalIds = @{}
        $reader = Get-MtZta -Section Reader
        if ($reader) {
            try {
                $raSync = & $reader.GetRows 'RoleAssignment' { param($r) $r.roleDefinitionId -eq $syncRoleTemplateId }
                foreach ($r in @($raSync)) { if ($r.principalId) { $syncPrincipalIds[[string]$r.principalId] = $true } }
            } catch { }
        }

        # Pick a sample privileged user — prefer DuckDB (cheap), fall back to Graph
        # via /roleManagement/directory/roleAssignments which works without DuckDB.
        # Skip break-glass (covered by separate dedicated CA) and sync accounts
        # (interactive MFA isn't the right control surface for them).
        $isExcludedSample = {
            param($u)
            if (-not $u) { return $true }
            if ($u.id -and $syncPrincipalIds.ContainsKey([string]$u.id)) { return $true }
            if ($u.userPrincipalName -and $u.userPrincipalName -match '^Sync_') { return $true }
            return [bool](Test-MtZtaIsEmergencyAccess -Id $u.id -UserPrincipalName $u.userPrincipalName)
        }
        $sampleUser = $null
        if ($zta.Database -and $zta.Database.Query) {
            try {
                $candidates = & $zta.Database.Query "SELECT u.id, u.userPrincipalName FROM `"User`" u JOIN RoleAssignment r ON r.principalId = u.id WHERE u.userType = 'member' AND u.accountEnabled = true LIMIT 20"
                foreach ($c in @($candidates)) {
                    if (-not (& $isExcludedSample $c)) { $sampleUser = $c; break }
                }
            } catch { }
        }
        if (-not $sampleUser -or -not $sampleUser.id) {
            try {
                $assignments = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleAssignments?$top=50' -ApiVersion beta
                foreach ($ra in @($assignments)) {
                    if (-not $ra.principalId) { continue }
                    try {
                        $user = Invoke-MtGraphRequest -RelativeUri "users/$($ra.principalId)?`$select=id,userPrincipalName,userType,accountEnabled" -ApiVersion beta -ErrorAction Stop
                    } catch { continue }
                    if ($user -and $user.userType -eq 'Member' -and $user.accountEnabled -and -not (& $isExcludedSample $user)) {
                        $sampleUser = $user
                        break
                    }
                }
            } catch { }
        }
        if (-not $sampleUser -or -not $sampleUser.id) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No eligible privileged user found (after excluding break-glass and Sync_* accounts) — cannot pick What-If subject for the privileged-MFA simulation.'
            return
        }

        $office365AppId = 'd3590ed6-52b3-4102-aeff-aad2292ab01c'

        try {
            $whatIf = Test-MtConditionalAccessWhatIf -UserId $sampleUser.id `
                                                     -IncludeApplications $office365AppId `
                                                     -ClientAppType 'browser' `
                                                     -DevicePlatform 'Windows'
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        # `Test-MtConditionalAccessWhatIf` returns the ARRAY of in-scope policy
        # evaluations (it does `Select-Object -ExpandProperty value` internally).
        # Each entry carries its own grantControls.authenticationStrength reference.
        # An earlier version treated $whatIf as a single object — PowerShell
        # member-access on an array returns arrays, which then stringify to a
        # space-joined blob in displayName ("BASE: MFA str - passkeys BASE: MFA
        # str - admins Phishing-resistant MFA ...") and produce a malformed URL
        # in the per-strength GET, so allowedCombinations were always "unavailable".
        #
        # Correct semantics: iterate each in-scope policy's authStrength reference,
        # de-duplicate by strength id, fetch allowedCombinations once per unique
        # strength, and report phish-resistant = ANY in-scope strength whose
        # allowedCombinations are all in the phish-resistant set. Because CA
        # policies compose with AND, having *any* phish-resistant-only strength
        # in scope forces the user's auth into the intersection of allowed
        # combinations — i.e. effectively phish-resistant.
        #
        # Phish-resistant set per Graph authenticationMethodModes:
        #   fido2, windowsHelloForBusiness, x509CertificateMultiFactor.
        # x509CertificateSingleFactor is single-factor — explicitly not MFA.
        $phishResistantSet = @('fido2','windowsHelloForBusiness','x509CertificateMultiFactor')
        $strengthSummaries = New-Object System.Collections.Generic.List[pscustomobject]
        $matchedPolicyLines = New-Object System.Collections.Generic.List[string]
        $seenStrengthIds = @{}
        $anyPhishResistant = $false

        foreach ($p in @($whatIf)) {
            if (-not $p) { continue }
            $polName  = if ($p.PSObject.Properties['displayName']) { [string]$p.displayName } else { '(no name)' }
            $polState = if ($p.PSObject.Properties['state'])       { [string]$p.state }       else { '' }
            $matchedPolicyLines.Add("- $polName ($polState)") | Out-Null

            $strRef = $null
            try { $strRef = $p.grantControls.authenticationStrength } catch { }
            if (-not $strRef) { continue }
            $sId   = [string]$strRef.id
            $sName = [string]$strRef.displayName
            if (-not $sId) { continue }
            if ($seenStrengthIds.ContainsKey($sId)) { continue }
            $seenStrengthIds[$sId] = $true

            $combos = @()
            try {
                $policy = Invoke-MtGraphRequest -RelativeUri "identity/conditionalAccess/authenticationStrength/policies/$sId" -ApiVersion beta -ErrorAction Stop
                $combos = @($policy.allowedCombinations)
            } catch { }

            $isPR = $false
            if ($combos.Count -gt 0) {
                $isPR = -not (@($combos | Where-Object { $_ -notin $phishResistantSet }).Count -gt 0)
            }
            if ($isPR) { $anyPhishResistant = $true }
            $strengthSummaries.Add([pscustomobject]@{
                Name             = $sName
                Id               = $sId
                Combinations     = $combos
                IsPhishResistant = $isPR
            }) | Out-Null
        }

        $isPhishResistant = $anyPhishResistant

        $strengthTable = if ($strengthSummaries.Count -gt 0) {
            ($strengthSummaries | ForEach-Object {
                $combo = if ($_.Combinations.Count -gt 0) { ($_.Combinations | Sort-Object -Unique) -join ', ' } else { '(unavailable)' }
                $pr = if ($_.IsPhishResistant) { 'yes' } else { 'no' }
                "| ``$($_.Name)`` | $combo | $pr |"
            }) -join "`n"
        } else { '| _(no authentication strength returned by any in-scope policy)_ | — | — |' }

        $matchedPolicies = if ($matchedPolicyLines.Count -gt 0) {
            ($matchedPolicyLines | Select-Object -First 5) -join "`n"
        } else { '_no CA policies in scope._' }

        $result = @"
| Field | Value |
|---|---|
| Sample privileged user | ``$($sampleUser.userPrincipalName)`` |
| Simulated app | Office 365 |
| Client | browser / Windows |
| In-scope policies | $(@($whatIf).Count) |
| Distinct auth-strength references | $($strengthSummaries.Count) |
| **Any phish-resistant authStrength in scope?** | **$isPhishResistant** |

### Authentication strengths in scope

| Strength | Allowed combinations | Phish-resistant? |
|---|---|---|
$strengthTable

### Policies in scope (first 5)

$matchedPolicies
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $isPhishResistant | Should -BeTrue
    }

    It 'MT.Zta.1132: CA What-If: legacy-auth client is blocked. See https://maester.dev/docs/tests/MT.Zta.1132' `
       -Tag 'MT.Zta.1132','Severity:Medium','ConditionalAccess','WhatIf','Beta','LegacyAuth' {

        $description = @'
## What this test checks
Fires when the Identity pillar Failed count is ≥ 5 (proxy for "tenant Identity posture is in active drift"). Simulates a sign-in via legacy-auth (`exchangeActiveSync`) and asserts the grant is `block`.

Many tenants have multiple "Block legacy auth" policies that compose oddly with exclusions. What-If is the only reliable way to verify the actual outcome.

## How to remediate
1. Conditional Access → New / edit policy → target All users → Conditions → Client apps → check Exchange ActiveSync clients + Other clients.
2. Grant: Block access.
3. Re-run; the simulation should return block.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $summary = Get-MtZta -Section Summary
        if (-not $summary -or $summary.IdentityFailed -lt 5) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "Identity-pillar Failed count ($(if ($summary) { $summary.IdentityFailed } else { 'n/a' })) below trigger threshold (5) — legacy-auth What-If not applicable."
            return
        }

        # Sample non-privileged user.
        $sampleUser = $null
        if ($zta.Database -and $zta.Database.Query) {
            try {
                $sampleUser = & $zta.Database.Query "SELECT id, userPrincipalName FROM `"User`" WHERE userType = 'member' AND accountEnabled = true LIMIT 1" | Select-Object -First 1
            } catch { }
        }
        if (-not $sampleUser) {
            try {
                $rows = Invoke-MtGraphRequest -RelativeUri 'users?$filter=accountEnabled eq true and userType eq ''Member''&$top=1&$select=id,userPrincipalName' -ApiVersion beta
                $sampleUser = @($rows)[0]
            } catch {
                Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
                return
            }
        }
        if (-not $sampleUser -or -not $sampleUser.id) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'Could not pick a sample user.'
            return
        }

        $office365AppId = 'd3590ed6-52b3-4102-aeff-aad2292ab01c'

        try {
            $whatIf = Test-MtConditionalAccessWhatIf -UserId $sampleUser.id `
                                                     -IncludeApplications $office365AppId `
                                                     -ClientAppType 'exchangeActiveSync'
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        $controls = @($whatIf.grantControls.builtInControls)
        $blocked = ($controls -contains 'block')

        $matchedPolicies = if ($whatIf.policies) {
            ($whatIf.policies | Select-Object -First 5 | ForEach-Object { "- $($_.displayName)" }) -join "`n"
        } else { '_no CA policies in scope._' }

        $result = @"
| Field | Value |
|---|---|
| Sample user | ``$($sampleUser.userPrincipalName)`` |
| Client | exchangeActiveSync (legacy auth) |
| Returned builtInControls | $(($controls | Sort-Object -Unique) -join ', ') |
| **Blocked?** | **$blocked** |

### Policies in scope (first 5)

$matchedPolicies
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $blocked | Should -BeTrue
    }

    It 'MT.Zta.1133: Sign-ins not covered by Conditional Access stay below threshold. See https://maester.dev/docs/tests/MT.Zta.1133' `
       -Tag 'MT.Zta.1133','Severity:High','ConditionalAccess','SignIn','Coverage' {

        $description = @'
## What this test checks
Streams the ZTA `SignIn` table and counts rows where `conditionalAccessStatus`
is `notApplied` — i.e. the sign-in completed without ANY Conditional Access
policy evaluating it. Asserts the ratio stays below the configured threshold
(default 5%).

This is the **data-side** complement to MT.Zta.1130 / 1131 / 1132. Those
three call `Test-MtConditionalAccessWhatIf` to simulate what WOULD happen for
a sample user; 1133 reads the historical sign-in stream and answers what
actually DID happen — which user-app combinations escape the CA net in
practice.

Mirrors the "No CA applied" metric ZTA's own HTML report surfaces in its
`TenantInfo.OverviewCaMfaAllUsers` Sankey. Failing this test means a
non-trivial share of real sign-ins authenticated without CA gating —
typically guests, service principals, specific apps in "Other Cloud Apps",
or specific client-app types (e.g. legacy auth) escaping CA scope.

## How to remediate
1. Open the sample table below; identify the top users with most
   `notApplied` sign-ins.
2. Entra ID → Sign-in logs → filter by one of those users → Conditional
   Access tab on a recent sign-in. The "Not applied" line shows which
   condition(s) excluded the sign-in from every policy in scope.
3. Common gap shapes:
   - **Guests** without a guest-targeted CA → add a B2B / external-user policy.
   - **Service principals** signing in → add a service-principal-targeted CA
     (Microsoft Entra ID P2 / Workload Identities Premium).
   - **Specific applications** excluded from CA scope → review per-app
     exclusions on top policies.
   - **Specific client app types** (e.g. exchangeActiveSync, other) →
     ensure a legacy-auth-block CA exists and matches the client type.
4. Add a catch-all "Block by default" CA targeting the gap surface. Save
   as Report-only, monitor for a week, then enable.

## Related Maester core tests (read together)
This is the **only data-side coverage check** in the entire Maester test corpus. The Maester core CA family inspects POLICY STATE (does a CA with the right grant exist?); none of them tell you whether the policies actually cover the sign-ins they were intended to cover.

Policy-state counterparts (all "is there a CA that ...?"):

- `MT.1001` — at least one CA configured with device compliance requirement.
- `MT.1003` / `MT.1004` — at least one CA targeting all cloud apps / all users.
- `MT.1005` — all CAs exclude at least one break-glass account.
- `MT.1006` / `MT.1007` / `MT.1008` — at least one CA requires MFA.
- `MT.1009` / `MT.1010` / `MT.1011` — block legacy auth / require auth context / secure named-location use.
- `CISA.MS.AAD.1.1` — legacy authentication SHALL be blocked.

**Joint reading**:

- Maester core CA tests Passed + ``MT.Zta.1133`` Passed → policies exist AND they actually cover ≥99% of sign-ins (default 1% bypass band). ✅
- Maester core CA tests Passed + ``MT.Zta.1133`` Failed → the right policies exist but a non-trivial share of sign-ins escape them. **Triage by looking at the user / app / clientApp top-offenders sample below.** Common root causes: guest sign-ins without a guest-targeted CA, service-principal sign-ins, app exclusions on top policies, legacy-auth client types not blocked.
- Maester core CA tests Failed + ``MT.Zta.1133`` Passed → unusual; the named CISA-flavored policies aren't present but some OTHER CA happens to cover sign-ins. Solid by luck, fragile by design — add the missing named policies before this changes.

A 0% bypass rate is the right target. Anything above that is gap surface waiting to be exploited.
'@

        $zta = Get-MtZta
        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded.'
            return
        }
        $reader = Get-MtZta -Section Reader
        if (-not $reader) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No Tier 1/Tier 2 reader available.'
            return
        }

        try {
            $total = 0
            $statusCounts = @{}
            $notAppliedByUser = @{}
            & $reader.GetRows 'SignIn' | ForEach-Object {
                $total++
                $status = if ($_.conditionalAccessStatus) { [string]$_.conditionalAccessStatus } else { '(none)' }
                if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
                $statusCounts[$status]++
                if ($status -eq 'notApplied' -and $_.userId) {
                    $uid = [string]$_.userId
                    if (-not $notAppliedByUser.ContainsKey($uid)) { $notAppliedByUser[$uid] = 0 }
                    $notAppliedByUser[$uid]++
                }
            }
            $notApplied = if ($statusCounts.ContainsKey('notApplied')) { $statusCounts['notApplied'] } else { 0 }
        }
        catch {
            Add-MtTestResultDetail -Description $description -SkippedBecause Error -SkippedError $_
            return
        }

        # Statistical-relevance gate. Tiny lab tenants with < 100 sign-ins can
        # trip a 5% threshold off a single bypass; that's not signal.
        if ($total -lt 100) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "Sign-in history too small ($total rows) for statistical relevance — need ≥ 100 sign-ins to evaluate CA bypass rate."
            return
        }

        # Threshold in PERCENT — operator-tunable via ZtaSettings.Thresholds.
        # Default 0: every sign-in MUST be processed by some CA policy. The
        # statistical-relevance gate above (skip when total < 100 sign-ins)
        # already filters out tenants where the metric isn't meaningful, so
        # zero-tolerance is the right default at the policy layer. Operators
        # who want a warn-band can raise the threshold per tenant.
        $threshold = Get-MtZtaThreshold -TestId 'MT.Zta.1133' -Default 0
        $notAppliedPct = [math]::Round(($notApplied / $total) * 100, 1)

        # Resolve top-10 violators with UPN + userType from the User table.
        $userIdx = $null
        try { $userIdx = & $reader.BuildIndex 'User' 'id' } catch { }
        $topUsersRows = @($notAppliedByUser.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)
        $topUsersTable = if ($topUsersRows.Count -gt 0) {
            ($topUsersRows | ForEach-Object {
                $uid = $_.Key; $count = $_.Value
                $u = if ($userIdx) { $userIdx[$uid] } else { $null }
                $upn = if ($u -and $u.userPrincipalName) { $u.userPrincipalName } else { '(unresolved)' }
                $userType = if ($u -and $u.userType) { $u.userType } else { '?' }
                "| $upn | $userType | $count |"
            }) -join "`n"
        } else { '_no per-user `notApplied` sign-ins detected._' }

        $statusBreakdown = ($statusCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
            $pct = if ($total -gt 0) { [math]::Round(($_.Value / $total) * 100, 1) } else { 0 }
            "- ``$($_.Key)``: $($_.Value) ($pct`%)"
        }) -join "`n"

        $result = @"
| Metric | Value | Threshold |
|---|---|---|
| Total sign-ins evaluated | $total | n/a |
| Sign-ins with ``conditionalAccessStatus = 'notApplied'`` | **$notApplied** | n/a |
| **% bypassing CA entirely** | **$notAppliedPct%** | < $threshold% |
| Distinct users with at least one bypass | $($notAppliedByUser.Count) | n/a |

### Top 10 users by 'notApplied' sign-in count

| UPN | userType | notApplied count |
|---|---|---|
$topUsersTable

### Full ``conditionalAccessStatus`` distribution

$statusBreakdown
"@

        Add-MtTestResultDetail -Description $description -Result $result
        $notAppliedPct | Should -BeLessThan $threshold -Because (
            "Over the window represented in the ZTA SignIn export, $notAppliedPct% of $total sign-ins ($notApplied) " +
            "completed without ANY Conditional Access policy evaluating them. The configured ceiling is ${threshold}%. " +
            'Identify the top users above in Entra ID → Sign-in logs → Conditional Access tab to see which condition(s) excluded them.'
        )
    }
}
