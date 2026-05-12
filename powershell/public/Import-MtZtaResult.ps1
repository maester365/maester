function Import-MtZtaResult {
    <#
    .SYNOPSIS
        Loads a Zero Trust Assessment (ZTA) result bundle into Maester so subsequent tests
        can focus on the areas ZTA flagged.

    .DESCRIPTION
        Resolves a ZTA result source (local path, Azure Blob URI, or Azure Artifacts
        Universal Package reference) via `Resolve-MtZtaArtifact`, validates the bundle
        contains the expected files (manifest.json + ZeroTrustAssessmentReport.json + db/zt.db),
        opens the DuckDB database read-only via `Read-MtZtaDatabase` (with JSON fallback on
        any failure), checks freshness via `Test-MtZtaFreshness`, and populates the
        module-private `$script:MtZtaContext` with the normalised data.

        Idempotent — subsequent calls with the same source short-circuit.

        No-ops gracefully when -ZtaResultsPath is `$null` or empty (keeps vanilla
        `Invoke-Maester` runs byte-identical to upstream).

    .PARAMETER ZtaResultsPath
        ZTA result source string. Three patterns recognised, in priority order:
          1. https://<account>.blob.core.windows.net/...   - Azure Blob (SAS in URI / WIF / -Identity)
          2. upkg://<org>/<project>/<feed>/<name>@<ver>     - Azure Artifacts Universal Package
          3. <local path>                                   - folder, .tar.gz, or .zip

    .PARAMETER FreshnessDays
        Override the default 14-day freshness threshold. Stale runs proceed (warn-but-proceed)
        but set `$script:MtZtaContext.IsStale = $true`.

    .PARAMETER ForceJsonFallback
        Skip DuckDB entirely and use the JSON-only path. Useful on Linux without the
        DuckDB.NET native binary or for repro tests.

    .PARAMETER ExpectedTenantId
        Optional tenant-id pin. When set, the manifest's tenantId must match exactly or
        the load aborts before any test runs. Cross-tenant data leakage guard.

    .PARAMETER ZtaSettings
        The `ZtaSettings` block from `maester-config.json` (already deserialised), passed
        through to subsequent cmdlets via `$script:MtZtaContext.ZtaSettings`. Drives:
          - CategoryMappings (Get-MtZta -Section FlaggedUsers, Get-MtZtaRecommendedTag)
          - SeverityEscalationRules (Update-MtSeverityFromZta)
          - DataDrivenSettings (Group-MtZtaFlaggedIdentity caps)
          - PillarTagMap (Get-MtZtaRecommendedTag pillar-tag union)
        Optional — when omitted, callers default to vendor-neutral baselines.

    .PARAMETER GlobalSettings
        The `GlobalSettings` block from `maester-config.json` (Maester's standard
        section). Today only `EmergencyAccessAccounts` is consumed: it is normalised
        and surfaced via `Get-MtZta -Section EmergencyAccessAccounts` and used by
        `Test-MtZtaIsEmergencyAccess` to mark legitimate break-glass identities as
        compliant-by-design in tests like MT.Zta.1107 (permanent Global Admins).
        Each entry can be a string (UPN or GUID) OR an object with `id` /
        `userPrincipalName` / `displayName` properties — all three shapes accepted.

    .EXAMPLE
        Import-MtZtaResult -ZtaResultsPath .\zta-results-2026-05-01.tar.gz

    .EXAMPLE
        Import-MtZtaResult -ZtaResultsPath 'https://contoso-sec.blob.core.windows.net/zta/2026-05-01.tar.gz'

    .EXAMPLE
        Import-MtZtaResult -ZtaResultsPath 'upkg://OnTrask-Security/Assessments/zta-results/customer-a-2026-05-01@1.0.0'

    .EXAMPLE
        Import-MtZtaResult -ZtaResultsPath .\zta -ForceJsonFallback

    .LINK
        https://maester.dev/docs/commands/Import-MtZtaResult

    .LINK
        https://maester.dev/docs/zero-trust-assessment
    #>
    # PSScriptAnalyzer wants singular nouns; the plural alias preserves backward compatibility.
    [Alias('Import-MtZtaResults')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $ZtaResultsPath,

        [Parameter(Mandatory = $false)]
        [int] $FreshnessDays = 14,

        [Parameter(Mandatory = $false)]
        [switch] $ForceJsonFallback,

        [Parameter(Mandatory = $false)]
        [string] $ExpectedTenantId,

        [Parameter(Mandatory = $false)]
        [object] $ZtaSettings,

        [Parameter(Mandatory = $false)]
        [object] $GlobalSettings
    )

    # Normalise GlobalSettings.EmergencyAccessAccounts. Three accepted input shapes:
    #   1. plain string UPN: "breakglass1@contoso.onmicrosoft.com"
    #   2. plain string GUID: "12345678-1234-1234-1234-123456789012"
    #   3. object: { id?, userPrincipalName?, displayName? }
    function ConvertTo-MtZtaEmergencyAccessNormalized {
        param([object] $Settings)
        if (-not $Settings) { return @() }
        if (-not $Settings.PSObject.Properties['EmergencyAccessAccounts']) { return @() }
        $raw = @($Settings.EmergencyAccessAccounts)
        if ($raw.Count -eq 0) { return @() }
        $normalized = New-Object System.Collections.Generic.List[pscustomobject]
        foreach ($entry in $raw) {
            if (-not $entry) { continue }
            if ($entry -is [string]) {
                $s = $entry.Trim()
                if (-not $s) { continue }
                # GUID heuristic — 36-char xxxx-xxxx-... shape with hyphens.
                if ($s -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    $normalized.Add([pscustomobject]@{ Id = $s; UserPrincipalName = $null; DisplayName = $null })
                } else {
                    # UPN-shaped string — anything containing '@' is treated as a UPN.
                    $normalized.Add([pscustomobject]@{ Id = $null; UserPrincipalName = $s; DisplayName = $null })
                }
            } else {
                $id  = if ($entry.PSObject.Properties['id'])                { [string]$entry.id }                else { $null }
                $upn = if ($entry.PSObject.Properties['userPrincipalName']) { [string]$entry.userPrincipalName } else { $null }
                $dn  = if ($entry.PSObject.Properties['displayName'])       { [string]$entry.displayName }       else { $null }
                if ($id -or $upn) {
                    $normalized.Add([pscustomobject]@{ Id = $id; UserPrincipalName = $upn; DisplayName = $dn })
                }
            }
        }
        return ,@($normalized.ToArray())
    }

    if ([string]::IsNullOrWhiteSpace($ZtaResultsPath)) {
        Write-Verbose 'Import-MtZtaResult: -ZtaResultsPath empty; ZTA context not loaded.'
        $script:MtZtaContext = $null
        return
    }

    # Idempotent short-circuit: same source, already loaded.
    if ($script:MtZtaContext -and $script:MtZtaContext.Source -eq $ZtaResultsPath) {
        Write-Verbose "Import-MtZtaResult: source unchanged ('$ZtaResultsPath'); reusing existing context."
        return
    }

    Write-Verbose "Import-MtZtaResult: resolving $ZtaResultsPath"
    $bundlePath = Resolve-MtZtaArtifact -Source $ZtaResultsPath

    $manifestPath = Join-Path $bundlePath 'manifest.json'
    $reportPath   = Join-Path $bundlePath 'ZeroTrustAssessmentReport.json'
    $dbPath       = Join-Path $bundlePath 'db/zt.db'

    if (-not (Test-Path $reportPath)) {
        throw "Import-MtZtaResult: bundle at '$bundlePath' is missing ZeroTrustAssessmentReport.json. Cannot proceed even with JSON fallback."
    }

    $manifest = $null
    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Warning "Import-MtZtaResult: manifest.json present but unreadable ($($_.Exception.Message)). Falling through to report-only metadata."
            $manifest = $null
        }
    }
    else {
        Write-Verbose "Import-MtZtaResult: no manifest.json at $manifestPath; deriving metadata from ZeroTrustAssessmentReport.json only."
    }

    if ($ExpectedTenantId -and $manifest -and $manifest.PSObject.Properties['tenantId']) {
        if ($manifest.tenantId -ne $ExpectedTenantId) {
            throw "Import-MtZtaResult: tenant mismatch. Manifest tenant '$($manifest.tenantId)' != expected '$ExpectedTenantId'. Refusing to load to prevent cross-tenant data leakage."
        }
    }

    $report = $null
    try {
        $report = Get-Content $reportPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Import-MtZtaResult: ZeroTrustAssessmentReport.json unreadable ($($_.Exception.Message)). Bundle at '$bundlePath' is corrupt."
    }

    # Tier 1 (JSON shadow) is the universal floor. Always populate.
    $jsonExport = $null
    try {
        $jsonExport = Read-MtZtaJsonExport -BundlePath $bundlePath
        Write-Verbose "Import-MtZtaResult: JSON-shadow tier loaded ($($jsonExport.Tables.Count) tables)."
    }
    catch {
        Write-Warning "Import-MtZtaResult: JSON shadow not readable ($($_.Exception.Message)). DuckDB tier may still work."
    }

    # Tier 2 (DuckDB) is opportunistic — returns $null on miss rather than throwing,
    # so the JSON tier carries the load when DuckDB is unavailable.
    $database = $null
    $dbStatus = 'NotAttempted'
    if (-not $ForceJsonFallback) {
        if (Test-Path $dbPath) {
            try {
                $database = Read-MtZtaDatabase -DatabasePath $dbPath
                $dbStatus = if ($database) { 'Loaded' } else { 'JsonOnlyMode' }
                if ($database) {
                    Write-Verbose "Import-MtZtaResult: DuckDB tier loaded ($($database.Tables.Count) tables)."
                } else {
                    Write-Verbose "Import-MtZtaResult: DuckDB tier unavailable; JSON tier is authoritative."
                }
            }
            catch {
                Write-Verbose "Import-MtZtaResult: DuckDB tier failed ($($_.Exception.Message)); JSON tier is authoritative."
                $dbStatus = "JsonOnlyMode: $($_.Exception.Message)"
                $database = $null
            }
        }
        else {
            Write-Verbose "Import-MtZtaResult: $dbPath not present; JSON tier is authoritative."
            $dbStatus = 'NoDbFile'
        }
    }
    else {
        $dbStatus = 'ForcedJsonFallback'
    }

    $freshness = Test-MtZtaFreshness -BundlePath $bundlePath -FreshnessDays $FreshnessDays
    if ($freshness.IsStale) {
        Write-Warning "ZTA artifact is stale: $($freshness.AgeDays) days old (threshold: $($freshness.Threshold) days, source: $($freshness.TimestampSource)). Tests will run but findings may not reflect current tenant state."
    }

    $script:MtZtaContext = [pscustomobject]@{
        Source        = $ZtaResultsPath
        BundlePath    = $bundlePath
        Manifest      = $manifest
        Tests         = $report.Tests
        Report        = $report
        Database      = $database
        DatabaseStatus= $dbStatus
        Freshness     = $freshness
        IsStale       = $freshness.IsStale
        TenantId      = if ($manifest -and $manifest.PSObject.Properties['tenantId']) { $manifest.tenantId } elseif ($report.PSObject.Properties['TenantId']) { $report.TenantId } else { $null }
        TenantName    = if ($manifest -and $manifest.PSObject.Properties['tenantName']) { $manifest.tenantName } elseif ($report.PSObject.Properties['TenantName']) { $report.TenantName } else { $null }
        ZtaSettings   = $ZtaSettings
        GlobalSettings = $GlobalSettings
        EmergencyAccessAccounts = (ConvertTo-MtZtaEmergencyAccessNormalized -Settings $GlobalSettings)
        JsonExport    = $jsonExport
        LoadedAt      = [datetime]::UtcNow
    }

    Write-Verbose "Import-MtZtaResult: context loaded for tenant $($script:MtZtaContext.TenantName) ($($script:MtZtaContext.TenantId)) — $($report.Tests.Count) tests, DB status: $dbStatus, freshness: $($freshness.AgeDays)d via $($freshness.TimestampSource)."
}
