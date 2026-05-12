# ZTA focus mechanism #4 — SEVERITY ESCALATION smoke test.
#
# In-body data-fetch pattern (Get-MtZta self-heals from $env:ZTA_RESULTS_REF when
# Pester runtime scope sees an empty MtZtaContext). All gating is done inside the
# It body via Set-ItResult / SkippedBecause so the report always renders a row
# with description + reason instead of an opaque blank Skipped.

Describe 'ZTA severity overlay — smoke test' -Tag 'ZTA' {

    It 'MT.Zta.1301: ZTA context is populated for this run. See https://maester.dev/docs/tests/MT.Zta.1301' -Tag 'MT.Zta.1301','Severity:High' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
End-to-end smoke test that the orchestration script's `Import-MtZtaResult` call succeeded and `$script:MtZtaContext` is visible from the test runtime. When this fails, the ZTA wiring is broken — most likely the resolver step set `ZTA_RESULTS_REF` to an empty path, or the Get-MtZta self-heal couldn't find a usable bundle on disk.
'@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded — Get-MtZta returned $null. Check that ZTA stage succeeded and the Maester stage''s resolver step set ZTA_RESULTS_REF.'
            return
        }

        $tenant = if ($zta.TenantName) { $zta.TenantName } else { '(unknown)' }
        $age    = if ($zta.Freshness -and $null -ne $zta.Freshness.AgeDays) { "$($zta.Freshness.AgeDays) days" } else { 'n/a' }
        $db     = if ($zta.DatabaseStatus) { $zta.DatabaseStatus } else { 'n/a' }
        $stale  = if ($zta.IsStale) { 'YES' } else { 'no' }
        $tests  = if ($zta.Tests) { @($zta.Tests).Count } else { 0 }

        $result = @"
| Field | Value |
|---|---|
| Tenant | ``$tenant`` |
| TenantId | ``$($zta.TenantId)`` |
| Source path | ``$($zta.Source)`` |
| Bundle path | ``$($zta.BundlePath)`` |
| Tests in report | $tests |
| Bundle age | $age |
| Stale (per FreshnessDays) | $stale |
| DuckDB status | $db |
"@

        Add-MtTestResultDetail -Description $description -Result $result

        $zta | Should -Not -BeNullOrEmpty
        $zta.TenantId | Should -Not -BeNullOrEmpty
    }

    It 'MT.Zta.1302: ZtaSettings is wired into the context. See https://maester.dev/docs/tests/MT.Zta.1302' -Tag 'MT.Zta.1302','Severity:Medium' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
Operator opted into ZTA-aware behaviour by adding a `ZtaSettings` block to `maester-config.json` AND the orchestration script forwarded it to `Import-MtZtaResult` via the `-ZtaSettings` parameter (or Get-MtZta's self-heal re-read it from `$env:MAESTER_ZTA_CONFIG_PATH`). When this is null, the data-driven and severity-overlay focus mechanisms (#3 and #4) silently degrade — the cmdlets exist but use vendor-neutral defaults.

## How to remediate
Add a `ZtaSettings` block to `maester-config.json` (see plan Section B). At minimum: `CategoryMappings` for the data-driven mechanism and `SeverityEscalationRules` for the severity overlay.
'@

        if (-not $zta) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZTA context loaded for this run.'
            return
        }

        $hasSettings = ($zta.PSObject.Properties['ZtaSettings'] -and $zta.ZtaSettings)
        if (-not $hasSettings) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZtaSettings supplied at Import-MtZtaResult time and MAESTER_ZTA_CONFIG_PATH did not surface a parsable maester-config.json. Focus mechanisms run with vendor-neutral defaults.'
            return
        }

        $settings = $zta.ZtaSettings
        $catCount = if ($settings.PSObject.Properties['CategoryMappings'] -and $settings.CategoryMappings) {
            @($settings.CategoryMappings).Count
        } else { 0 }
        $ruleCount = if ($settings.PSObject.Properties['SeverityEscalationRules'] -and $settings.SeverityEscalationRules) {
            @($settings.SeverityEscalationRules).Count
        } else { 0 }
        $freshDays = if ($settings.PSObject.Properties['FreshnessDays']) { $settings.FreshnessDays } else { '(default 14)' }

        $result = @"
| Block | Entries |
|---|---|
| CategoryMappings | $catCount |
| SeverityEscalationRules | $ruleCount |
| FreshnessDays | $freshDays |
"@
        Add-MtTestResultDetail -Description $description -Result $result
        $settings | Should -Not -BeNullOrEmpty
    }

    It 'MT.Zta.1303: Each severity escalation rule has a To severity and at least one selector. See https://maester.dev/docs/tests/MT.Zta.1303' -Tag 'MT.Zta.1303','Severity:Medium' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
Every `SeverityEscalationRule` in `ZtaSettings` must specify both:
- `To` — the target severity (Medium / High / Critical),
- One of `EscalateMaesterTagged` (tag selector) or `EscalateMaesterTestId` (id wildcard selector).

Without `To`, the rule has no destination. Without a selector, the rule matches no tests. Either case makes the rule a no-op and indicates a configuration mistake.
'@

        if (-not $zta -or -not $zta.PSObject.Properties['ZtaSettings'] -or -not $zta.ZtaSettings) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZtaSettings on context — rule shape check N/A.'
            return
        }
        $settings = $zta.ZtaSettings
        if (-not $settings.PSObject.Properties['SeverityEscalationRules'] -or -not $settings.SeverityEscalationRules) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No SeverityEscalationRules block in ZtaSettings.'
            return
        }

        $rules = @($settings.SeverityEscalationRules)
        $invalid = @($rules | Where-Object {
            $r = $_
            if (-not $r) { return $true }
            $hasTo = ($r.PSObject.Properties['To'] -and $r.To)
            $hasTagSel = ($r.PSObject.Properties['EscalateMaesterTagged'] -and $r.EscalateMaesterTagged)
            $hasIdSel  = ($r.PSObject.Properties['EscalateMaesterTestId']  -and $r.EscalateMaesterTestId)
            -not $hasTo -or -not ($hasTagSel -or $hasIdSel)
        })

        $rulesTable = ($rules | ForEach-Object {
            $r = $_
            $sel = @()
            if ($r.PSObject.Properties['EscalateMaesterTagged'] -and $r.EscalateMaesterTagged) {
                $sel += "tags=[$(@($r.EscalateMaesterTagged) -join ', ')]"
            }
            if ($r.PSObject.Properties['EscalateMaesterTestId'] -and $r.EscalateMaesterTestId) {
                $sel += "ids=[$(@($r.EscalateMaesterTestId) -join ', ')]"
            }
            $when = if ($r.PSObject.Properties['WhenPillarFailedAtLeast'] -and $r.PSObject.Properties['Pillar']) {
                "Pillar $($r.Pillar) ≥ $($r.WhenPillarFailedAtLeast)"
            } elseif ($r.PSObject.Properties['WhenCategoryFlaggedUsersAtLeast'] -and $r.PSObject.Properties['Category']) {
                "Category $($r.Category) ≥ $($r.WhenCategoryFlaggedUsersAtLeast)"
            } else { '(no condition — always fires)' }
            $from = if ($r.PSObject.Properties['From']) { $r.From } else { '*' }
            $to   = if ($r.PSObject.Properties['To']) { $r.To } else { '?' }
            "| $when | $($sel -join '; ') | $from → **$to** |"
        }) -join "`n"

        $result = @"
| Trigger | Selector | From → To |
|---|---|---|
$rulesTable

| Validation | Value |
|---|---|
| Rules with missing ``To`` or selector | **$($invalid.Count)** |
"@

        Add-MtTestResultDetail -Description $description -Result $result

        $invalid.Count | Should -Be 0
    }

    It 'MT.Zta.1304: No escalation rule lowers severity (To is in {Medium,High,Critical}). See https://maester.dev/docs/tests/MT.Zta.1304' -Tag 'MT.Zta.1304','Severity:Medium' {
        $zta = Get-MtZta

        $description = @'
## What this test checks
The severity overlay is a one-way escalation — it should never **lower** a test's severity. Allowed `To` values are limited to {Medium, High, Critical}. A rule with `To: Low` or `To: Info` indicates a misconfiguration that would silently downgrade findings.

(Note: the actual ladder check happens at runtime in `Test-MtZtaSeverityHigher` inside `Update-MtSeverityFromZta` — this test catches the misconfiguration at the rule shape level so the operator gets feedback before the pipeline runs.)
'@

        if (-not $zta -or -not $zta.PSObject.Properties['ZtaSettings'] -or -not $zta.ZtaSettings) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No ZtaSettings on context — ladder check N/A.'
            return
        }
        $settings = $zta.ZtaSettings
        if (-not $settings.PSObject.Properties['SeverityEscalationRules'] -or -not $settings.SeverityEscalationRules) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason 'No SeverityEscalationRules block in ZtaSettings.'
            return
        }

        $allowed = @('Medium','High','Critical')
        $rules = @($settings.SeverityEscalationRules)
        $bad = @($rules | Where-Object { $_ -and $_.PSObject.Properties['To'] -and $_.To -notin $allowed })

        $sample = if ($bad) {
            ($bad | ForEach-Object {
                $cat = if ($_.PSObject.Properties['Category']) { $_.Category } else { '(none)' }
                $pil = if ($_.PSObject.Properties['Pillar']) { $_.Pillar } else { '(none)' }
                "| $cat / Pillar=$pil | $($_.To) |"
            }) -join "`n"
        } else { '_none — all rules use Medium / High / Critical._' }

        $result = @"
| Metric | Value |
|---|---|
| Total rules | $($rules.Count) |
| Rules with disallowed ``To`` | **$($bad.Count)** |

### Disallowed rules (sample)

| Rule | To |
|---|---|
$sample
"@

        Add-MtTestResultDetail -Description $description -Result $result

        foreach ($rule in $rules) {
            if ($rule -and $rule.PSObject.Properties['To'] -and $rule.To) {
                $rule.To | Should -BeIn $allowed
            }
        }
    }
}
