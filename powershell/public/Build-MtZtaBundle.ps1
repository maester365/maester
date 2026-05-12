function Build-MtZtaBundle {
    <#
    .SYNOPSIS
        Compiles a single hashtable of ZTA-derived analytics for embedding into
        the Maester report's HTML/JSON output (consumed by the ZTA tab in the
        React report).

    .DESCRIPTION
        The Maester HTML report inlines its result JSON via `Get-MtHtmlReport`.
        The ZTA tab needs a few extra fields beyond the standard test rows:
        bundle metadata, per-pillar summary, inventory counts, and curated
        analytics (auth-method posture, privileged exposure, application
        credential hygiene, device trust mix).

        This helper walks `$script:MtZtaContext` (populated by
        `Import-MtZtaResult`) and emits one hashtable that the orchestrator
        injects into the Maester result object as `ZtaBundle`. When no ZTA
        context is loaded the function returns `$null` — the orchestrator
        skips augmentation and the ZTA tab degrades gracefully.

        Reuses `Get-MtZtaAuthMethodSet` for method classification and the same
        Tier-0 role-template constants used by the ZTA-aware test surface.

    .OUTPUTS
        [hashtable] or $null

    .EXAMPLE
        # In the orchestrator, right after Invoke-Maester returns:
        $bundle = Build-MtZtaBundle
        if ($bundle) {
            $result | Add-Member -NotePropertyName 'ZtaBundle' -NotePropertyValue $bundle -Force
        }

    .LINK
        https://maester.dev/docs/commands/Build-MtZtaBundle

    .LINK
        https://maester.dev/docs/zero-trust-assessment
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if (-not $script:MtZtaContext) {
        Write-Verbose 'Build-MtZtaBundle: no MtZtaContext loaded; returning $null.'
        return $null
    }
    $ctx = $script:MtZtaContext

    # Pick the highest-tier reader available: DuckDB if loaded, else JSON shadow.
    $reader = $null
    if ($ctx.PSObject.Properties['Database'] -and $ctx.Database) {
        $reader = $ctx.Database
    } elseif ($ctx.PSObject.Properties['JsonExport'] -and $ctx.JsonExport) {
        $reader = $ctx.JsonExport
    }

    # Curated Tier-0 / critical-impact role-template IDs.
    $tier0Roles = [ordered]@{
        '62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
        'e8611ab8-bd05-4f8c-9bd9-2ec6c2b4a771' = 'Privileged Role Administrator'
        '7be44c8a-adaf-4e2a-84d6-ab2649e08a13' = 'Privileged Authentication Administrator'
        'fe930be7-5e62-47db-91af-98c3a49a38b1' = 'User Administrator'
        '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3' = 'Application Administrator'
        '158c047a-c907-4556-b7ef-446551a6b5f7' = 'Cloud Application Administrator'
        '194ae4cb-b126-40b2-bd5b-6091b380977d' = 'Security Administrator'
        'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9' = 'Conditional Access Administrator'
        '8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2' = 'Hybrid Identity Administrator'
        '3a2c62db-5318-420d-8d74-23affee5d9d5' = 'Intune Administrator'
        '29232cdf-9323-42fd-ade2-1d097af3e4de' = 'Exchange Administrator'
        'f28a1f50-f6e7-4571-818b-6a12f2af6b6c' = 'SharePoint Administrator'
        '69091246-20e8-4a56-aa4d-066075b2a7a8' = 'Teams Administrator'
    }

    # ExecutedAt / ZtaVersion are on the nested Report/Manifest objects — drill in.
    $executedAt = $null
    if ($ctx.PSObject.Properties['Report'] -and $ctx.Report -and $ctx.Report.PSObject.Properties['ExecutedAt']) {
        $executedAt = $ctx.Report.ExecutedAt
    }
    # Manifest is preferred (packager-stamped), but unpackaged bundles only carry
    # the report — fall back to the report's CurrentVersion field.
    $ztaVersion = $null
    if ($ctx.PSObject.Properties['Manifest'] -and $ctx.Manifest -and $ctx.Manifest.PSObject.Properties['ztaVersion']) {
        $ztaVersion = $ctx.Manifest.ztaVersion
    } elseif ($ctx.PSObject.Properties['Report'] -and $ctx.Report -and $ctx.Report.PSObject.Properties['CurrentVersion']) {
        $ztaVersion = $ctx.Report.CurrentVersion
    }

    # ── Top-level metadata + Freshness + Summary ────────────────────────────
    $bundle = @{
        TenantId             = $ctx.TenantId
        TenantName           = $ctx.TenantName
        ExecutedAt           = $executedAt
        ZtaAssessmentVersion = $ztaVersion
        BundlePath           = if ($ctx.PSObject.Properties['BundlePath']) { $ctx.BundlePath } else { $null }
        Source               = if ($ctx.PSObject.Properties['Source']) { $ctx.Source } else { $null }
        Tier                 = if ($reader -and $reader.PSObject.Properties['Tier']) { $reader.Tier } else { 'None' }
        IsStale              = [bool]$ctx.IsStale
        Freshness            = $null
        Summary              = $null
        Inventory            = @{}
        Applications         = @{}
        Devices              = @{}
        Privileged           = @{}
        AuthMethodScore      = @{}
        ConditionalAccess    = @{}
    }
    if ($ctx.PSObject.Properties['Freshness'] -and $ctx.Freshness) {
        $bundle.Freshness = @{
            AgeDays         = $ctx.Freshness.AgeDays
            Threshold       = $ctx.Freshness.Threshold
            IsStale         = [bool]$ctx.Freshness.IsStale
            TimestampSource = $ctx.Freshness.TimestampSource
        }
    }
    # Reuse Get-MtZta -Section Summary so the bundle matches what tests see.
    # Best-effort — any failure leaves $bundle.Summary as $null and the ZTA tab
    # degrades gracefully.
    try {
        $summary = Get-MtZta -Section Summary -ErrorAction Stop
        if ($summary) { $bundle.Summary = $summary }
    } catch {
        Write-Verbose "Build-MtZtaBundle: Get-MtZta -Section Summary failed ($($_.Exception.Message)); bundle.Summary stays null."
    }

    # ── Bail if no reader: bundle still has metadata + summary, just no analytics
    if (-not $reader) {
        Write-Verbose 'Build-MtZtaBundle: no Tier 1/Tier 2 reader; emitting metadata-only bundle.'
        return $bundle
    }

    # ── Inventory totals (cheap streaming counts) ────────────────────────────
    $tableTotals = [ordered]@{
        Users                    = 'User'
        Devices                  = 'Device'
        Applications             = 'Application'
        ServicePrincipals        = 'ServicePrincipal'
        PermanentRoleAssignments = 'RoleAssignment'
        PimEligibleAssignments   = 'RoleEligibilityScheduleInstance'
    }
    foreach ($k in $tableTotals.Keys) {
        try {
            $rows = & $reader.GetRows $tableTotals[$k]
            $bundle.Inventory[$k] = @($rows).Count
        } catch {
            $bundle.Inventory[$k] = $null
            Write-Verbose "Build-MtZtaBundle: failed to count $($tableTotals[$k]): $_"
        }
    }

    # Member / Guest split of the User table — surfaced for the Tenant scale
    # card. These are derived directly from the User table (not from URD) so
    # they reflect the full population including users who never signed in.
    try {
        $allUsers = @(& $reader.GetRows 'User')
        $bundle.Inventory['MemberUsers'] = @($allUsers | Where-Object { $_.userType -eq 'member' }).Count
        $bundle.Inventory['GuestUsers']  = @($allUsers | Where-Object { $_.userType -eq 'guest'  }).Count
    } catch {
        $bundle.Inventory['MemberUsers'] = $null
        $bundle.Inventory['GuestUsers']  = $null
    }

    # Privileged principals (unique principalIds across RoleAssignment +
    # RoleEligibilityScheduleInstance). Counts every principal with at least
    # one permanent OR PIM-eligible directory role — used for the Tenant
    # scale "privileged" sub-cell.
    try {
        $privSet = @{}
        try {
            foreach ($r in @(& $reader.GetRows 'RoleAssignment')) {
                if ($r.principalId) { $privSet[[string]$r.principalId] = $true }
            }
        } catch {
            Write-Verbose "Build-MtZtaBundle: RoleAssignment table read failed ($($_.Exception.Message)); proceeding with PIM-eligible only."
        }
        try {
            foreach ($r in @(& $reader.GetRows 'RoleEligibilityScheduleInstance')) {
                if ($r.principalId) { $privSet[[string]$r.principalId] = $true }
            }
        } catch {
            Write-Verbose "Build-MtZtaBundle: RoleEligibilityScheduleInstance read failed ($($_.Exception.Message)); proceeding with permanent only."
        }
        $bundle.Inventory['PrivilegedPrincipalsTotal'] = $privSet.Count
    } catch {
        $bundle.Inventory['PrivilegedPrincipalsTotal'] = $null
    }

    # ── Applications analytics ───────────────────────────────────────────────
    try {
        $appRows = @(& $reader.GetRows 'Application')
        $now = [datetime]::UtcNow
        $hasExpired = {
            param($app)
            foreach ($c in @($app.passwordCredentials)) {
                if (-not $c.endDateTime) { continue }
                try { if ([datetime]::Parse([string]$c.endDateTime).ToUniversalTime() -lt $now) { return $true } }
                catch { Write-Verbose "Build-MtZtaBundle: unparseable endDateTime '$($c.endDateTime)' on app — skipping credential." }
            }
            return $false
        }
        $withPwd = @($appRows | Where-Object { @($_.passwordCredentials).Count -gt 0 })
        $withKey = @($appRows | Where-Object { @($_.keyCredentials).Count -gt 0 })
        $bundle.Applications = @{
            Total                     = $appRows.Count
            WithPasswordCredentials   = $withPwd.Count
            WithKeyCredentials        = $withKey.Count
            CredentialFree            = @($appRows | Where-Object { @($_.passwordCredentials).Count -eq 0 -and @($_.keyCredentials).Count -eq 0 }).Count
            ExpiredSecretsStillPresent = @($withPwd | Where-Object { & $hasExpired $_ }).Count
            MultiTenant               = @($appRows | Where-Object { $_.signInAudience -in @('AzureADMultipleOrgs','AzureADandPersonalMicrosoftAccount') }).Count
            BySignInAudience          = @{}
        }
        foreach ($g in ($appRows | Group-Object signInAudience)) {
            $name = if ($g.Name) { [string]$g.Name } else { '(unset)' }
            $bundle.Applications.BySignInAudience[$name] = $g.Count
        }
    } catch {
        Write-Verbose "Build-MtZtaBundle: Application analytics failed: $_"
    }

    # ── Devices analytics ────────────────────────────────────────────────────
    try {
        $devRows = @(& $reader.GetRows 'Device')
        $cutoff = [datetime]::UtcNow.AddDays(-90)
        $isStale = {
            param($d)
            if ($d.accountEnabled -ne $true) { return $false }
            if (-not $d.approximateLastSignInDateTime) { return $false }
            try { return [datetime]::Parse([string]$d.approximateLastSignInDateTime).ToUniversalTime() -lt $cutoff } catch { return $false }
        }
        $bundle.Devices = @{
            Total            = $devRows.Count
            IsCompliantTrue  = @($devRows | Where-Object { $_.isCompliant -eq $true }).Count
            IsCompliantFalse = @($devRows | Where-Object { $_.isCompliant -eq $false }).Count
            IsManagedTrue    = @($devRows | Where-Object { $_.isManaged -eq $true }).Count
            AccountEnabled   = @($devRows | Where-Object { $_.accountEnabled -eq $true }).Count
            StaleDevices     = @($devRows | Where-Object { & $isStale $_ }).Count
            ByTrustType      = @{}
            ByOs             = @{}
        }
        foreach ($g in ($devRows | Group-Object trustType)) {
            $name = if ($g.Name) { [string]$g.Name } else { '(empty)' }
            $bundle.Devices.ByTrustType[$name] = $g.Count
        }
        foreach ($g in ($devRows | Group-Object operatingSystem)) {
            $name = if ($g.Name) { [string]$g.Name } else { '(empty)' }
            $bundle.Devices.ByOs[$name] = $g.Count
        }
    } catch {
        Write-Verbose "Build-MtZtaBundle: Device analytics failed: $_"
    }

    # ── Conditional Access policy posture ───────────────────────────────────
    # Live Graph fetch — Maester is connected at this point in the orchestrator
    # so re-using Invoke-MtGraphRequest is the cheapest path. Falls back to
    # empty hashtable on any failure so the ZTA tab card degrades gracefully.
    try {
        $caRows = @()
        try {
            $caRaw = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/policies' -ApiVersion v1.0 -ErrorAction Stop
            $caRows = @($caRaw)
        } catch {
            try {
                $caRaw = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/policies' -ApiVersion beta -ErrorAction Stop
                $caRows = @($caRaw)
            } catch {
                Write-Verbose "Build-MtZtaBundle: CA policies fetch failed (both v1.0 and beta): $_"
            }
        }

        $enabled    = @($caRows | Where-Object { $_.state -eq 'enabled' })
        $reportOnly = @($caRows | Where-Object { $_.state -eq 'enabledForReportingButNotEnforced' })
        $disabled   = @($caRows | Where-Object { $_.state -eq 'disabled' })

        # Build a strengthId → isPhishResistant map by inspecting each strength
        # policy's `allowedCombinations`. Display-name matching silently misses
        # custom strengths whose names don't contain "phish"; inspecting
        # allowedCombinations is the only reliable approach.
        # Phish-resistant set per Graph authenticationMethodModes:
        #   fido2, windowsHelloForBusiness, x509CertificateMultiFactor.
        $phishStrengths = @{}
        $phishResistantSet = @('fido2','windowsHelloForBusiness','x509CertificateMultiFactor')
        try {
            $strengthPolicies = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/authenticationStrength/policies' -ApiVersion v1.0 -ErrorAction Stop
            foreach ($sp in @($strengthPolicies)) {
                if (-not $sp.id) { continue }
                $combos = @($sp.allowedCombinations)
                if ($combos.Count -eq 0) { continue }
                $allPhish = $true
                foreach ($c in $combos) {
                    if ($c -notin $phishResistantSet) { $allPhish = $false; break }
                }
                $phishStrengths[[string]$sp.id] = $allPhish
            }
        } catch {
            Write-Verbose "Build-MtZtaBundle: authStrength policies fetch failed: $_"
        }

        # Categorise enabled policies:
        #   MfaRequired    enforced policy requiring MFA — via builtIn 'mfa' OR
        #                  authenticationStrength (modern tenants use authStrength,
        #                  not builtIn 'mfa')
        #   PhishResistant subset of MfaRequired where all allowedCombinations
        #                  are phish-resistant
        #   Block          enforced policy with builtIn 'block'
        #   NoCaApplied    enforced policy with neither MFA nor block (e.g.
        #                  compliantDevice-only, passwordChange, session-only)
        # NB: `$rNoCaApplied` counts enforced POLICIES with no MFA or block;
        # it is surfaced as PolicyNoMfa in the output hashtable to distinguish
        # it from the sign-in funnel's NoCaApplied (users not gated by any CA).
        $rMfa = 0; $rPhish = 0; $rBlock = 0; $rNoCaApplied = 0
        $rCompliantDevice = 0
        $hasUserExclusion = 0; $hasGroupExclusion = 0
        foreach ($p in $enabled) {
            $controls = @($p.grantControls.builtInControls)
            $hasMfaBuiltin = $controls -contains 'mfa'
            $hasBlock      = $controls -contains 'block'
            $hasCompliant  = $controls -contains 'compliantDevice'
            $strengthId    = if ($p.grantControls.authenticationStrength) { [string]$p.grantControls.authenticationStrength.id } else { $null }
            $hasAuthStr    = [bool]$strengthId
            $isPhish       = $hasAuthStr -and $phishStrengths.ContainsKey($strengthId) -and $phishStrengths[$strengthId] -eq $true

            if ($hasBlock) {
                $rBlock++
            }
            elseif ($hasMfaBuiltin -or $hasAuthStr) {
                $rMfa++
                if ($isPhish) { $rPhish++ }
            }
            else {
                $rNoCaApplied++
            }
            if ($hasCompliant) { $rCompliantDevice++ }

            if (@($p.conditions.users.excludeUsers).Count -gt 0) { $hasUserExclusion++ }
            if (@($p.conditions.users.excludeGroups).Count -gt 0) { $hasGroupExclusion++ }
        }

        # Sign-in funnel — ZTA pre-computes this as a Sankey node list at
        # TenantInfo.OverviewCaMfaAllUsers.nodes. We reuse the same numbers so
        # the ZTA tab's "No CA applied" matches the standalone ZTA HTML report.
        #   User sign in → CA applied | No CA applied
        #   CA applied   → MFA | No MFA
        $signIn = @{
            Total            = 0
            CaApplied        = 0
            NoCaApplied      = 0
            Mfa              = 0
            NoMfa            = 0
            MfaProtectedPct  = 0
            Description      = $null
        }
        try {
            $sankey = $null
            if ($ctx.PSObject.Properties['Report'] -and $ctx.Report -and
                $ctx.Report.PSObject.Properties['TenantInfo'] -and $ctx.Report.TenantInfo -and
                $ctx.Report.TenantInfo.PSObject.Properties['OverviewCaMfaAllUsers']) {
                $sankey = $ctx.Report.TenantInfo.OverviewCaMfaAllUsers
            }
            if ($sankey -and $sankey.PSObject.Properties['nodes']) {
                foreach ($n in @($sankey.nodes)) {
                    if ($n.source -eq 'User sign in' -and $n.target -eq 'No CA applied') { $signIn.NoCaApplied = [int]$n.value }
                    if ($n.source -eq 'User sign in' -and $n.target -eq 'CA applied')    { $signIn.CaApplied   = [int]$n.value }
                    if ($n.source -eq 'CA applied'   -and $n.target -eq 'MFA')           { $signIn.Mfa         = [int]$n.value }
                    if ($n.source -eq 'CA applied'   -and $n.target -eq 'No MFA')        { $signIn.NoMfa       = [int]$n.value }
                }
                $signIn.Total = $signIn.CaApplied + $signIn.NoCaApplied
                if ($signIn.Total -gt 0) {
                    $signIn.MfaProtectedPct = [math]::Round(($signIn.Mfa / $signIn.Total) * 100, 1)
                }
                if ($sankey.PSObject.Properties['description']) {
                    $signIn.Description = [string]$sankey.description
                }
            }
        } catch {
            Write-Verbose "Build-MtZtaBundle: Sign-in funnel extraction failed: $_"
        }

        $bundle.ConditionalAccess = @{
            Total                     = $caRows.Count
            Enabled                   = $enabled.Count
            ReportOnly                = $reportOnly.Count
            Disabled                  = $disabled.Count
            MfaRequired               = $rMfa
            PhishResistant            = $rPhish
            Block                     = $rBlock
            # Policy-level "no MFA + no block" renamed to PolicyNoMfa to avoid
            # colliding with the sign-in funnel's NoCaApplied.
            PolicyNoMfa               = $rNoCaApplied
            CompliantDevice           = $rCompliantDevice
            EnabledWithUserExclusion  = $hasUserExclusion
            EnabledWithGroupExclusion = $hasGroupExclusion
            SignIn                    = $signIn
        }
    } catch {
        Write-Verbose "Build-MtZtaBundle: ConditionalAccess analytics failed: $_"
    }

    # ── Privileged-access analytics ──────────────────────────────────────────
    # `$raRows` and `$pimRows` are also used by the auth-method-score block below
    # to compute the Privileged population, so they're declared before the try.
    $raRows  = @()
    $pimRows = @()
    try {
        $raRows  = @(& $reader.GetRows 'RoleAssignment')
        try { $pimRows = @(& $reader.GetRows 'RoleEligibilityScheduleInstance') }
        catch { Write-Verbose "Build-MtZtaBundle: PIM-eligible table read failed ($($_.Exception.Message)); proceeding with permanent only." }
        $rdef = @()
        try { $rdef = @(& $reader.GetRows 'RoleDefinition') }
        catch { Write-Verbose "Build-MtZtaBundle: RoleDefinition table read failed ($($_.Exception.Message)); role displayNames will fall back to template GUIDs." }
        $rdefIndex = @{}
        foreach ($r in $rdef) { if ($r.id) { $rdefIndex[[string]$r.id] = $r } }

        $tier0Perm = 0
        $byRole = @{}
        foreach ($r in $raRows) {
            $rid = [string]$r.roleDefinitionId
            $rname = if ($rdefIndex.ContainsKey($rid)) { $rdefIndex[$rid].displayName } else { $rid }
            if (-not $byRole.ContainsKey($rname)) { $byRole[$rname] = 0 }
            $byRole[$rname]++
            if ($tier0Roles.Contains($rid)) { $tier0Perm++ }
        }
        $topRole = $byRole.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        $declared = 0
        try { $declared = @(Get-MtZta -Section EmergencyAccessAccounts).Count }
        catch { Write-Verbose "Build-MtZtaBundle: Get-MtZta -Section EmergencyAccessAccounts failed ($($_.Exception.Message)); declared count stays 0." }

        # Service principals
        $spRows = @(& $reader.GetRows 'ServicePrincipal')
        $spByType = @{}
        foreach ($g in ($spRows | Group-Object servicePrincipalType)) {
            $name = if ($g.Name) { [string]$g.Name } else { '(empty)' }
            $spByType[$name] = $g.Count
        }

        $bundle.Privileged = @{
            PermanentTotal        = $raRows.Count
            PimEligibleTotal      = $pimRows.Count
            Tier0Permanent        = $tier0Perm
            TopPermanentRole      = if ($topRole) { $topRole.Key } else { $null }
            TopPermanentRoleCount = if ($topRole) { $topRole.Value } else { 0 }
            BreakGlassDeclared    = $declared
            ByRole                = $byRole
            ServicePrincipals     = @{
                Total              = $spRows.Count
                Enabled            = @($spRows | Where-Object { $_.accountEnabled -eq $true }).Count
                WithPasswordCreds  = @($spRows | Where-Object { @($_.passwordCredentials).Count -gt 0 }).Count
                WithKeyCreds       = @($spRows | Where-Object { @($_.keyCredentials).Count -gt 0 }).Count
                ByType             = $spByType
            }
        }
    } catch {
        Write-Verbose "Build-MtZtaBundle: Privileged analytics failed: $_"
    }

    # Auth-method posture (PhishResistant / Mixed / PhishableOnly / NoMfa).
    try {
        $methods = Get-MtZtaAuthMethodSet
        $phishR  = $methods.PhishResistant
        $phish   = $methods.Phishable
        $urd = @(& $reader.GetRows 'UserRegistrationDetails')

        $populations = @{
            Members    = @($urd | Where-Object { $_.userType -eq 'member' })
            Guests     = @($urd | Where-Object { $_.userType -eq 'guest' })
            Privileged = @()
        }
        # Privileged population = principals with at least one permanent OR
        # PIM-eligible role assignment. Restricting to RoleAssignment alone misses
        # the typical "everything is in PIM" tenant where most admins are eligible-only.
        $privIds = @{}
        if ($raRows) {
            foreach ($r in $raRows) { if ($r.principalId) { $privIds[[string]$r.principalId] = $true } }
        }
        if ($pimRows) {
            foreach ($r in $pimRows) { if ($r.principalId) { $privIds[[string]$r.principalId] = $true } }
        }
        if ($privIds.Count -gt 0) {
            $populations.Privileged = @($urd | Where-Object { $_.id -and $privIds.ContainsKey([string]$_.id) })
        }

        $score = {
            param($pop)
            $noMfa = 0; $weakOnly = 0; $strongOnly = 0; $mixed = 0
            foreach ($u in $pop) {
                $m = if ($u.methodsRegistered) { @($u.methodsRegistered) } else { @() }
                if ($m.Count -eq 0) { $noMfa++; continue }
                $hasStrong = (@($m | Where-Object { $_ -in $phishR }).Count -gt 0)
                $hasWeak   = (@($m | Where-Object { $_ -in $phish }).Count -gt 0)
                if ($hasStrong -and $hasWeak)      { $mixed++ }
                elseif ($hasStrong -and -not $hasWeak) { $strongOnly++ }
                elseif ($hasWeak -and -not $hasStrong) { $weakOnly++ }
                else { $weakOnly++ }   # only single-factor / unrecognised → treat as weak
            }
            return @{
                Total              = @($pop).Count
                NoMfa              = $noMfa
                PhishableOnly      = $weakOnly
                Mixed              = $mixed
                PhishResistantOnly = $strongOnly
            }
        }

        $bundle.AuthMethodScore = @{
            All        = & $score $urd
            Members    = & $score $populations.Members
            Guests     = & $score $populations.Guests
            Privileged = & $score $populations.Privileged
        }
    } catch {
        Write-Verbose "Build-MtZtaBundle: AuthMethodScore failed: $_"
    }

    return $bundle
}
