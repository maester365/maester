function Get-MtZta {
    <#
    .SYNOPSIS
        Returns the ZTA context loaded by `Import-MtZtaResult`, or `$null` if ZTA was not ingested.

    .DESCRIPTION
        Accessor used inside Pester `BeforeDiscovery` and `It` blocks to consume ZTA findings.
        Returns `$null` when ZTA was not loaded so tests can `Set-ItResult -Skipped` cleanly
        without having to know whether the operator opted into ZTA-focused mode.

    .PARAMETER Section
        Which section of the ZTA context to return. When omitted, returns the full
        `$script:MtZtaContext` object.

          Tests        - raw Tests[] array from ZeroTrustAssessmentReport.json
          Manifest     - manifest.json contents (tenant, run time, ZTA version, hashes)
          Database     - DuckDB query context (Tier 2 — when ZTA's loaded assembly available)
          JsonExport   - JSON-shadow query context (Tier 1 — always populated when bundle has zt-export/)
          Reader       - highest-tier-available reader (Database if loaded, else JsonExport).
                         Use this for tests that want to read tables without caring which tier
                         services the request.
          EmergencyAccessAccounts
                       - normalised break-glass list from GlobalSettings.EmergencyAccessAccounts.
                         Returns [pscustomobject[]] with { Id, UserPrincipalName, DisplayName }.
          Summary      - per-pillar fail counts + ratios + tenant id
          FlaggedUsers - output of Group-MtZtaFlaggedIdentity

    .EXAMPLE
        BeforeDiscovery { $script:zta = Get-MtZta -Section Tests }
        It 'Identity pillar has fewer than 30 failures' -Skip:(-not $script:zta) {
            ($script:zta | Where-Object { $_.TestPillar -eq 'Identity' -and $_.TestStatus -eq 'Failed' }).Count |
                Should -BeLessThan 30
        }

    .EXAMPLE
        $summary = Get-MtZta -Section Summary
        if ($summary.IdentityFailRatio -ge 0.5) { ... }

    .EXAMPLE
        $buckets = Get-MtZta -Section FlaggedUsers
        Describe 'Per-user posture' -ForEach $buckets { ... }

    .LINK
        https://maester.dev/docs/commands/Get-MtZta

    .LINK
        https://maester.dev/docs/zero-trust-assessment
    #>
    [CmdletBinding()]
    [OutputType([object], [object[]])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Tests', 'Manifest', 'Database', 'JsonExport', 'Reader', 'EmergencyAccessAccounts', 'Summary', 'FlaggedUsers')]
        [string] $Section
    )

    # Self-heal: Pester sometimes spawns a new runspace where $script: resets to null.
    # Re-bootstrap from env vars when context is null but the orchestrator left the
    # path behind via $env:ZTA_RESULTS_REF.
    if (-not $script:MtZtaContext -and $env:ZTA_RESULTS_REF -and (Test-Path $env:ZTA_RESULTS_REF)) {
        Write-Verbose "Get-MtZta: context null but ZTA_RESULTS_REF=$($env:ZTA_RESULTS_REF) — bootstrapping."
        $bootstrap = @{ ZtaResultsPath = $env:ZTA_RESULTS_REF; ErrorAction = 'SilentlyContinue' }
        if ($env:MAESTER_ZTA_CONFIG_PATH -and (Test-Path $env:MAESTER_ZTA_CONFIG_PATH)) {
            try {
                $cfg = Get-Content $env:MAESTER_ZTA_CONFIG_PATH -Raw | ConvertFrom-Json -ErrorAction Stop
                if ($cfg.PSObject.Properties['ZtaSettings'] -and $cfg.ZtaSettings) {
                    $bootstrap['ZtaSettings'] = $cfg.ZtaSettings
                }
                # GlobalSettings carries EmergencyAccessAccounts.
                if ($cfg.PSObject.Properties['GlobalSettings'] -and $cfg.GlobalSettings) {
                    $bootstrap['GlobalSettings'] = $cfg.GlobalSettings
                }
            } catch {
                Write-Verbose "Get-MtZta: settings re-read from MAESTER_ZTA_CONFIG_PATH failed ($($_.Exception.Message)) — bootstrapping without settings."
            }
        }
        try { Import-MtZtaResult @bootstrap } catch {
            Write-Verbose "Get-MtZta: bootstrap Import-MtZtaResult failed ($($_.Exception.Message))."
        }
    }

    if (-not $script:MtZtaContext) {
        Write-Verbose 'Get-MtZta: $script:MtZtaContext is not set. Run Import-MtZtaResult first.'
        return $null
    }

    if (-not $Section) {
        return $script:MtZtaContext
    }

    switch ($Section) {
        'Tests'    { return $script:MtZtaContext.Tests }
        'Manifest' { return $script:MtZtaContext.Manifest }
        'Database' { return $script:MtZtaContext.Database }
        'JsonExport' { return $script:MtZtaContext.JsonExport }
        'Reader' {
            # Returns the highest-tier-available reader: DuckDB if loaded, else JSON.
            # Validates GetRows is a usable scriptblock before returning — Pester child
            # runspaces can lose closure context, leaving a truthy object whose .GetRows
            # is $null, which produces a cryptic pipeline error at the call site.
            # Returning $null here lets callers' `if (-not $reader)` guard Skip cleanly.
            $r = $script:MtZtaContext.Database
            if (-not $r) { $r = $script:MtZtaContext.JsonExport }
            if (-not $r) { return $null }
            if (-not ($r.PSObject.Properties['GetRows']) -or -not ($r.GetRows -is [scriptblock])) {
                Write-Verbose 'Get-MtZta: reader present but GetRows is not a usable scriptblock (Pester scope context drop?). Returning $null so callers Skip cleanly.'
                return $null
            }
            return $r
        }
        'EmergencyAccessAccounts' {
            if (-not $script:MtZtaContext.PSObject.Properties['EmergencyAccessAccounts']) { return @() }
            return @($script:MtZtaContext.EmergencyAccessAccounts)
        }
        'Summary' {
            return Get-MtZtaSummary -Tests $script:MtZtaContext.Tests -TenantId $script:MtZtaContext.TenantId
        }
        'FlaggedUsers' {
            $settings = $script:MtZtaContext.ZtaSettings
            $mappings = @()
            $maxPerCat = 50
            $groupSimilar = $true
            if ($settings) {
                if ($settings.PSObject.Properties['CategoryMappings'] -and $settings.CategoryMappings) {
                    $mappings = @($settings.CategoryMappings)
                }
                if ($settings.PSObject.Properties['DataDrivenSettings'] -and $settings.DataDrivenSettings) {
                    if ($settings.DataDrivenSettings.PSObject.Properties['MaxUsersPerCategory']) {
                        $maxPerCat = [int]$settings.DataDrivenSettings.MaxUsersPerCategory
                    }
                    if ($settings.DataDrivenSettings.PSObject.Properties['GroupSimilar']) {
                        $groupSimilar = [bool]$settings.DataDrivenSettings.GroupSimilar
                    }
                }
            }

            return Group-MtZtaFlaggedIdentity `
                -Tests $script:MtZtaContext.Tests `
                -CategoryMappings $mappings `
                -ContextDatabase $script:MtZtaContext.Database `
                -MaxUsersPerCategory $maxPerCat `
                -GroupSimilar $groupSimilar
        }
    }
}

function Get-MtZtaSummary {
    <#
    .SYNOPSIS
        Internal helper — derives per-pillar fail counts and ratios from a Tests[] array.

    .DESCRIPTION
        Pillar-keyed summary used by Get-MtZta -Section Summary. Returns a flat object so
        Pester `-Skip:` expressions can chain .IdentityFailRatio etc. without traversal.

        Counts: Passed, Failed, Skipped, Investigate, Planned, Total.
        Ratios: <Pillar>FailRatio = Failed / max(1, Total - Skipped - Planned).
                Skipped/Planned excluded from denominator so a fully-licensed pillar with
                10 failures is comparable to one with 10 failures plus 50 skipped tests.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]] $Tests,

        [Parameter(Mandatory = $false)]
        [string] $TenantId
    )

    $pillars = 'Identity','Devices','Network','Data'
    $out = [ordered]@{ TenantId = $TenantId; TotalTests = @($Tests).Count }

    foreach ($p in $pillars) {
        $pillarTests = @($Tests | Where-Object { $_.TestPillar -eq $p })
        $passed       = @($pillarTests | Where-Object { $_.TestStatus -eq 'Passed' }).Count
        $failed       = @($pillarTests | Where-Object { $_.TestStatus -eq 'Failed' }).Count
        $skipped      = @($pillarTests | Where-Object { $_.TestStatus -eq 'Skipped' }).Count
        $investigate  = @($pillarTests | Where-Object { $_.TestStatus -eq 'Investigate' }).Count
        $planned      = @($pillarTests | Where-Object { $_.TestStatus -eq 'Planned' }).Count
        $denominator  = [math]::Max(1, $pillarTests.Count - $skipped - $planned)
        $failRatio    = [math]::Round($failed / $denominator, 4)

        $out["${p}Passed"]      = $passed
        $out["${p}Failed"]      = $failed
        $out["${p}Skipped"]     = $skipped
        $out["${p}Investigate"] = $investigate
        $out["${p}Planned"]     = $planned
        $out["${p}FailRatio"]   = $failRatio
    }

    return [pscustomobject]$out
}
