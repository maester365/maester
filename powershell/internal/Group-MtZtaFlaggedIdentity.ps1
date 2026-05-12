function Group-MtZtaFlaggedIdentity {
    <#
    .SYNOPSIS
        Internal: groups ZTA-failed identities into category buckets so Maester data-driven
        tests can iterate per-bucket.

    .DESCRIPTION
        Implements a 7-step "same-kind" bucketing algorithm. Consumes the JSON Tests[]
        (always present); optionally enriches from DuckDB when `$ContextDatabase` is
        supplied (Read-MtZtaDatabase output).

        Buckets are defined by `$CategoryMappings` (typically loaded from
        `ZtaSettings.CategoryMappings` in maester-config.json). Each test is matched
        against rules in order; first match wins. Unmatched tests fall into 'Other'.

        Algorithm:
          1. failed = Tests[] WHERE TestStatus='Failed'
          2. for each failed t: classify into category by CategoryMappings rules
                                emit user UPNs / objectIds extracted from TestResult markdown
          3. (optional) DuckDB enrichment unions:
                NoMFA              <- UserRegistrationDetails WHERE isMfaRegistered=false
                StaleSignIn        <- SignIn WHERE createdDateTime < 90 days ago (latest per user)
                NoCompliantDevice  <- Device WHERE isCompliant=false
                GuestUnconstrained <- User WHERE userType='Guest' (no CA coverage join — JSON-only proxy)
          4. dedupe by (UserId, Category)
          5. "same-kind" merge: collapse rows sharing Category + overlapping evidence
          6. cap each bucket at MaxUsersPerCategory; deterministic order by UPN
          7. return [{ Category, Pillar, Count, Group=[users] }, ...]

    .PARAMETER Tests
        The Tests[] array from a loaded ZTA report (typically `$script:MtZtaContext.Tests`).
        Required.

    .PARAMETER CategoryMappings
        Array of category-mapping rules (the `ZtaSettings.CategoryMappings` block).
        Each rule: { Category, MatchPillar, MatchCategoryAny, MatchTestIds (opt), MaesterTagBoost }.
        Empty/missing -> all failures fall into 'Other' (callers warn at >10%).

    .PARAMETER ContextDatabase
        Optional DuckDB context object from Read-MtZtaDatabase (`$script:MtZtaContext.Database`).
        When supplied, enrichment queries augment the JSON-derived buckets. Errors during
        enrichment are non-fatal — buckets still return JSON-only data.

    .PARAMETER MaxUsersPerCategory
        Cap per bucket. Default 50 (driven by `DataDrivenSettings.MaxUsersPerCategory`).

    .PARAMETER GroupSimilar
        Enable step 5 same-kind merging. Default $true.

    .OUTPUTS
        [pscustomobject[]] one entry per bucket:
            { Category, Pillar, Count, Group = [pscustomobject[]] }
        Each Group entry: { UserId, UserPrincipalName, Pillar, Category, Evidence (string[]) }
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]] $Tests,

        [Parameter(Mandatory = $false)]
        [object[]] $CategoryMappings = @(),

        [Parameter(Mandatory = $false)]
        [object] $ContextDatabase,

        [Parameter(Mandatory = $false)]
        [int] $MaxUsersPerCategory = 50,

        [Parameter(Mandatory = $false)]
        [bool] $GroupSimilar = $true
    )

    # Step 1 — failed only.
    $failed = @($Tests | Where-Object { $_.TestStatus -eq 'Failed' })

    # Step 2 — classify + emit JSON-derived users.
    $rows = @()  # flat: { UserId, UserPrincipalName, Pillar, Category, Evidence }

    foreach ($t in $failed) {
        $cat = Get-MtZtaCategoryForTest -Test $t -CategoryMappings $CategoryMappings

        # Extract user identifiers from TestResult markdown. ZTA produces freeform markdown;
        # the conservative parser pulls UPNs (email-shaped) and bare GUIDs (objectId).
        $users = @()
        if ($t.TestResult) {
            $resultText = [string]$t.TestResult
            $upnMatches  = [regex]::Matches($resultText, '\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b')
            $guidMatches = [regex]::Matches($resultText, '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b')

            foreach ($m in $upnMatches) {
                $users += [pscustomobject]@{
                    UserId            = $null
                    UserPrincipalName = $m.Value
                    Pillar            = $t.TestPillar
                    Category          = $cat
                    Evidence          = @("ZTA test $($t.TestId): $($t.TestTitle)")
                }
            }
            foreach ($m in $guidMatches) {
                # Only emit GUIDs that don't co-occur with an UPN already captured.
                $users += [pscustomobject]@{
                    UserId            = $m.Value
                    UserPrincipalName = $null
                    Pillar            = $t.TestPillar
                    Category          = $cat
                    Evidence          = @("ZTA test $($t.TestId): $($t.TestTitle)")
                }
            }
        }

        # Tests with no extractable identities still count as a category-level signal —
        # emit a synthetic placeholder so callers can render "(no users in markdown)".
        if (-not $users) {
            $users = @([pscustomobject]@{
                UserId            = $null
                UserPrincipalName = $null
                Pillar            = $t.TestPillar
                Category          = $cat
                Evidence          = @("ZTA test $($t.TestId): $($t.TestTitle) [test-level only]")
            })
        }

        $rows += $users
    }

    # Step 3 — DuckDB enrichment (best-effort).
    if ($ContextDatabase -and $ContextDatabase.Query) {
        try {
            # NoMFA
            $sql = "SELECT id, userPrincipalName FROM UserRegistrationDetails WHERE isMfaRegistered = false LIMIT $($MaxUsersPerCategory * 2)"
            $r = & $ContextDatabase.Query $sql
            foreach ($u in $r) {
                $rows += [pscustomobject]@{
                    UserId            = $u.id
                    UserPrincipalName = $u.userPrincipalName
                    Pillar            = 'Identity'
                    Category          = 'IdentityPosture'
                    Evidence          = @('UserRegistrationDetails.isMfaRegistered=false')
                }
            }
        }
        catch { Write-Verbose "Group-MtZtaFlaggedIdentity: NoMFA enrichment skipped ($($_.Exception.Message))" }

        try {
            # GuestUnconstrained — JSON-derivable proxy; no CA-coverage join.
            $sql = "SELECT id, userPrincipalName FROM `"User`" WHERE userType = 'Guest' AND accountEnabled = true LIMIT $($MaxUsersPerCategory * 2)"
            $r = & $ContextDatabase.Query $sql
            foreach ($u in $r) {
                $rows += [pscustomobject]@{
                    UserId            = $u.id
                    UserPrincipalName = $u.userPrincipalName
                    Pillar            = 'Identity'
                    Category          = 'GuestUnconstrained'
                    Evidence          = @('User.userType=Guest, accountEnabled=true')
                }
            }
        }
        catch { Write-Verbose "Group-MtZtaFlaggedIdentity: GuestUnconstrained enrichment skipped ($($_.Exception.Message))" }

        try {
            # NoCompliantDevice — owner is in the Device row's userId field if populated; otherwise
            # we still surface the device record under the user-level bucket as a device-class signal.
            $sql = "SELECT deviceId, displayName, isCompliant FROM Device WHERE isCompliant = false LIMIT $($MaxUsersPerCategory * 2)"
            $r = & $ContextDatabase.Query $sql
            foreach ($d in $r) {
                $rows += [pscustomobject]@{
                    UserId            = $d.deviceId
                    UserPrincipalName = $d.displayName
                    Pillar            = 'Devices'
                    Category          = 'DevicePosture'
                    Evidence          = @("Device.isCompliant=false ($($d.displayName))")
                }
            }
        }
        catch { Write-Verbose "Group-MtZtaFlaggedIdentity: NoCompliantDevice enrichment skipped ($($_.Exception.Message))" }
    }

    # Step 4 — dedupe by (UserId-or-UPN, Category). Merge Evidence arrays.
    $deduped = @{}
    foreach ($r in $rows) {
        $key = "$($r.Category)|$(if ($r.UserId) { $r.UserId } else { $r.UserPrincipalName })"
        if ($deduped.ContainsKey($key)) {
            $existing = $deduped[$key]
            $existing.Evidence = @($existing.Evidence + $r.Evidence | Select-Object -Unique)
        }
        else {
            $deduped[$key] = $r
        }
    }
    $merged = @($deduped.Values)

    # Step 5 — "same-kind" merge is already a side-effect of step 4 keying on Category.
    # The flag exists to allow callers to opt-out (set $GroupSimilar=$false to keep
    # one row per (test,user) pair instead). When false, return the pre-dedup rows.
    if (-not $GroupSimilar) { $merged = $rows }

    # Step 6 — group by Category, cap per bucket, deterministic order.
    $byCategory = $merged | Group-Object Category

    $result = foreach ($g in $byCategory) {
        $sorted = $g.Group | Sort-Object @{ Expression = { if ($_.UserPrincipalName) { $_.UserPrincipalName } else { [string]$_.UserId } } }
        $capped = $sorted | Select-Object -First $MaxUsersPerCategory

        # Pillar of a bucket = pillar of the first member (consistent within a category).
        $pillar = if ($capped) { $capped[0].Pillar } else { $null }

        [pscustomobject]@{
            Category = $g.Name
            Pillar   = $pillar
            Count    = @($g.Group).Count
            Group    = @($capped)
        }
    }

    # Plain array return so pipeline consumers see individual buckets — a leading
    # `,@($x)` would emit the entire array as a single pipeline item, breaking
    # `| Where-Object Category -eq 'X'`. Callers that need array-shape preservation
    # can wrap with @() at the call site.
    return $result
}

function Get-MtZtaCategoryForTest {
    <#
    .SYNOPSIS
        Internal helper: classifies a single ZTA test against a CategoryMappings rule list.
        First match wins. Returns 'Other' on no match.

    .DESCRIPTION
        Multi-pass match precedence (highest -> lowest):
          Pass 1: explicit MatchTestIds wildcard match against $Test.TestId
          Pass 2: explicit category match (MatchCategoryAny non-empty AND intersect $Test.TestCategory)
                  — applies to both pillar-specific and cross-cut (MatchPillar='*') rules.
          Pass 3: pillar-level catch-all (MatchCategoryAny empty AND MatchPillar matches the test pillar).
                  Cross-cut rules (MatchPillar='*') are NEVER catch-all by design.

        This means a "Privileged access" test under Identity pillar lands in PrivilegedAccess
        (the explicit cross-cut), not IdentityPosture (the pillar-level catch-all), regardless
        of declaration order. Operators only need order-independent rules.

        Pillar comparison is case-insensitive. Category comparison is case-insensitive
        and tolerates ZTA's free-text variants — comma/semicolon split for compound
        categories like "Credential management; Privileged access".
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)] [object] $Test,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [object[]] $CategoryMappings
    )

    if (-not $CategoryMappings -or $CategoryMappings.Count -eq 0) { return 'Other' }

    $testPillar   = if ($Test.TestPillar)   { [string]$Test.TestPillar }   else { '' }
    $testCategory = if ($Test.TestCategory) { [string]$Test.TestCategory } else { '' }
    $testId       = if ($Test.TestId)       { [string]$Test.TestId }       else { '' }

    # Split compound categories on ',' and ';' (e.g. "Credential management; Privileged access")
    $catParts = $testCategory -split '\s*[;,]\s*' | Where-Object { $_ }

    # Pass 1 — TestId wildcard match (highest priority).
    foreach ($rule in $CategoryMappings) {
        $matchTestIds = Get-MtZtaRuleMember -Rule $rule -Name 'MatchTestIds'
        if ($matchTestIds) {
            foreach ($pattern in @($matchTestIds)) {
                if ($testId -like $pattern) { return (Get-MtZtaRuleMember -Rule $rule -Name 'Category') }
            }
        }
    }

    # Pass 2 — explicit category match (pillar-gated). Wins over pillar-level catch-alls
    # regardless of declaration order. Cross-cut rules (MatchPillar='*') compete here too.
    foreach ($rule in $CategoryMappings) {
        $matchPillar     = Get-MtZtaRuleMember -Rule $rule -Name 'MatchPillar'
        $matchCategoryAny = Get-MtZtaRuleMember -Rule $rule -Name 'MatchCategoryAny'
        if ($null -eq $matchPillar) { continue }

        $rp = [string]$matchPillar
        $pillarMatches = ($rp -eq '*') -or ($rp -ieq $testPillar)
        if (-not $pillarMatches) { continue }

        $catList = if ($matchCategoryAny) { @($matchCategoryAny) } else { @() }
        if ($catList.Count -eq 0) { continue }   # pillar-level catch-all is pass 3

        foreach ($needle in $catList) {
            $needleNorm = ([string]$needle).Trim()
            foreach ($part in $catParts) {
                if ($part.Trim() -ieq $needleNorm) { return (Get-MtZtaRuleMember -Rule $rule -Name 'Category') }
            }
            if ($testCategory.Trim() -ieq $needleNorm) { return (Get-MtZtaRuleMember -Rule $rule -Name 'Category') }
        }
    }

    # Pass 3 — pillar-level catch-all (lowest priority). Cross-cuts cannot be catch-all.
    foreach ($rule in $CategoryMappings) {
        $matchPillar     = Get-MtZtaRuleMember -Rule $rule -Name 'MatchPillar'
        $matchCategoryAny = Get-MtZtaRuleMember -Rule $rule -Name 'MatchCategoryAny'
        if ($null -eq $matchPillar) { continue }

        $rp = [string]$matchPillar
        if ($rp -eq '*') { continue }                           # cross-cut is never catch-all
        if ($rp -ine $testPillar) { continue }

        $catList = if ($matchCategoryAny) { @($matchCategoryAny) } else { @() }
        if ($catList.Count -eq 0) { return (Get-MtZtaRuleMember -Rule $rule -Name 'Category') }
    }

    return 'Other'
}

function Get-MtZtaRuleMember {
    <#
    .SYNOPSIS
        Internal: pulls a named member from a CategoryMappings rule whether the rule is a
        [hashtable] (created via @{}) or a [pscustomobject] (created via ConvertFrom-Json).
        Returns $null when the member is absent.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Rule,
        [Parameter(Mandatory = $true)] [string] $Name
    )
    if ($Rule -is [System.Collections.IDictionary]) {
        if ($Rule.Contains($Name)) { return $Rule[$Name] }
        return $null
    }
    if ($Rule.PSObject.Properties[$Name]) { return $Rule.$Name }
    return $null
}
