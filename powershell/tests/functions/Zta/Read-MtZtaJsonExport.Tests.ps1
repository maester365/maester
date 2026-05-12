# Unit tests for Read-MtZtaJsonExport (Tier 1 JSON shadow reader).
# Tests that require a real export bundle skip at discovery time when the fixture
# path is not present, so the suite remains portable across machines.

$global:MtZtaJsonExportFixturePath = 'F:\ALZ\exports\assessments\platform\zta-report\zta-report'
$global:MtZtaJsonExportFixtureExists = Test-Path (Join-Path $global:MtZtaJsonExportFixturePath 'zt-export')

Describe 'Read-MtZtaJsonExport — Tier 1 JSON shadow reader' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixturePath = $global:MtZtaJsonExportFixturePath
    }

    Context 'Bundle resolution + schema baseline' -Skip:(-not $global:MtZtaJsonExportFixtureExists) {

        It 'opens the captured Platform bundle and discovers all 16 baseline tables' {
            $ctx = & $script:mod {
                param($p) Read-MtZtaJsonExport -BundlePath $p
            } $script:fixturePath
            try {
                $ctx                  | Should -Not -BeNullOrEmpty
                $ctx.Tier             | Should -Be 'JsonExport'
                $ctx.SupportsSql      | Should -BeTrue
                $ctx.Tables.Count     | Should -BeGreaterOrEqual 16
                $ctx.Tables           | Should -Contain 'User'
                $ctx.Tables           | Should -Contain 'SignIn'
                $ctx.Tables           | Should -Contain 'RoleAssignment'
            }
            finally { & $ctx.Dispose }
        }

        It 'throws when the bundle path does not exist' {
            $bogus = Join-Path ([System.IO.Path]::GetTempPath()) "no-zta-$([guid]::NewGuid())"
            { & $script:mod { param($p) Read-MtZtaJsonExport -BundlePath $p } $bogus } |
                Should -Throw -ExpectedMessage '*bundle path not found*'
        }

        It 'on a sparse/empty bundle, baseline tables are present (as known-empty) and GetRows returns @()' {
            # ZTA omits JSON folders for tables with 0 rows. Baseline tables must still
            # be reachable so callers can call GetRows without special-casing emptiness.
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "zta-sparse-$([guid]::NewGuid())"
            New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'zt-export/User') | Out-Null
            try {
                $ctx = & $script:mod { param($p) Read-MtZtaJsonExport -BundlePath $p } $tmp
                try {
                    $ctx.Tables | Should -Contain 'RoleAssignment'   # baseline-required, no folder
                    @(& $ctx.GetRows 'RoleAssignment')        | Should -BeNullOrEmpty
                    (& $ctx.HasTable 'RoleAssignment')        | Should -BeTrue
                }
                finally { & $ctx.Dispose }
            }
            finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
        }

        It 'allows narrow opens via -LimitToTables (skips schema baseline)' {
            $ctx = & $script:mod {
                param($p) Read-MtZtaJsonExport -BundlePath $p -LimitToTables 'User','RoleAssignment'
            } $script:fixturePath
            try {
                $ctx.Tables           | Should -Contain 'User'
                $ctx.Tables           | Should -Contain 'RoleAssignment'
                $ctx.Tables.Count     | Should -Be 2
            }
            finally { & $ctx.Dispose }
        }
    }

    Context 'GetRows streaming + count-parity with zt.db' -Skip:(-not $global:MtZtaJsonExportFixtureExists) {

        BeforeAll {
            $script:ctx = & $script:mod {
                param($p) Read-MtZtaJsonExport -BundlePath $p
            } $script:fixturePath
        }
        AfterAll { if ($script:ctx) { & $script:ctx.Dispose } }

        # Counts are approximate because the captured fixture is refreshed periodically.
        # The invariant verified is "table is populated AND streaming through all shards works".

        It 'GetRows User returns at least 10 rows (Platform tenant)' {
            $rows = & $script:ctx.GetRows 'User'
            @($rows).Count | Should -BeGreaterThan 10
        }

        It 'GetRows SignIn returns hundreds of rows (Platform tenant)' {
            $rows = & $script:ctx.GetRows 'SignIn'
            @($rows).Count | Should -BeGreaterThan 100
        }

        It 'GetRows ConfigurationPolicy aggregates across many shards (Platform tenant)' {
            $rows = & $script:ctx.GetRows 'ConfigurationPolicy'
            @($rows).Count | Should -BeGreaterThan 50
        }

        It 'GetRows with Predicate filters in-stream' {
            $pred = { param($r) $r.userType -eq 'Member' }
            $rows = & $script:ctx.GetRows 'User' $pred
            @($rows).Count | Should -BeGreaterThan 0
            ($rows | Where-Object { $_.userType -ne 'Member' }) | Should -BeNullOrEmpty
        }

        It 'GetRows with Top stops streaming after N rows' {
            $rows = & $script:ctx.GetRows 'SignIn' $null 10
            @($rows).Count | Should -Be 10
        }
    }

    Context 'BuildIndex + lookup' -Skip:(-not $global:MtZtaJsonExportFixtureExists) {

        BeforeAll {
            $script:ctx = & $script:mod {
                param($p) Read-MtZtaJsonExport -BundlePath $p
            } $script:fixturePath
        }
        AfterAll { if ($script:ctx) { & $script:ctx.Dispose } }

        It 'BuildIndex User by id returns a hashtable keyed by every user id' {
            $idx = & $script:ctx.BuildIndex 'User' 'id'
            $idx                | Should -BeOfType [hashtable]
            $idx.Count          | Should -BeGreaterThan 10
            ($idx.Values | Select-Object -First 1).PSObject.Properties['userPrincipalName'] | Should -Not -BeNullOrEmpty
        }

        It 'BuildIndex is cached — second call returns the same hashtable instance' {
            $idx1 = & $script:ctx.BuildIndex 'RoleAssignment' 'principalId'
            $idx2 = & $script:ctx.BuildIndex 'RoleAssignment' 'principalId'
            [object]::ReferenceEquals($idx1, $idx2) | Should -BeTrue
        }

        It 'BuildIndex on RoleAssignment by principalId enables anti-join lookups' {
            $idx = & $script:ctx.BuildIndex 'RoleAssignment' 'principalId'
            # For a non-privileged user lookup
            $nonPrivUsers = & $script:ctx.GetRows 'User' { param($u) -not $idx.ContainsKey($u.id) }
            @($nonPrivUsers).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Query (mini SQL adapter)' -Skip:(-not $global:MtZtaJsonExportFixtureExists) {

        BeforeAll {
            $script:ctx = & $script:mod {
                param($p) Read-MtZtaJsonExport -BundlePath $p
            } $script:fixturePath
        }
        AfterAll { if ($script:ctx) { & $script:ctx.Dispose } }

        It 'Query SELECT COUNT(*) returns the row count' {
            $r = & $script:ctx.Query 'SELECT COUNT(*) FROM User'
            $r[0].count_star | Should -BeGreaterThan 10
        }

        It 'Query SELECT COUNT(*) FROM <t> WHERE <col> = ''<v>'' filters' {
            $r = & $script:ctx.Query "SELECT COUNT(*) FROM RoleAssignment WHERE roleDefinitionId = '62e90394-69f5-4237-9190-012177145e10'"
            $r[0].count_star | Should -BeGreaterOrEqual 0   # depends on tenant; just confirms no throw
        }

        It 'Query SELECT * FROM <t> LIMIT 5 returns 5 rows' {
            $r = & $script:ctx.Query 'SELECT * FROM SignIn LIMIT 5'
            @($r).Count | Should -Be 5
        }

        It 'Query throws NotSupportedException for unsupported SQL' {
            {
                & $script:ctx.Query 'SELECT u.id FROM User u JOIN SignIn s ON s.userId = u.id'
            } | Should -Throw -ExceptionType ([System.NotSupportedException])
        }
    }

    Context 'HasTable / HasColumn introspection' -Skip:(-not $global:MtZtaJsonExportFixtureExists) {

        BeforeAll {
            $script:ctx = & $script:mod {
                param($p) Read-MtZtaJsonExport -BundlePath $p
            } $script:fixturePath
        }
        AfterAll { if ($script:ctx) { & $script:ctx.Dispose } }

        It 'HasTable returns true for known tables and false for unknown' {
            (& $script:ctx.HasTable 'User')             | Should -BeTrue
            (& $script:ctx.HasTable 'NonExistentTable') | Should -BeFalse
        }

        It 'HasColumn probes the first shard for the named property' {
            (& $script:ctx.HasColumn 'User' 'userPrincipalName') | Should -BeTrue
            (& $script:ctx.HasColumn 'User' 'NotARealColumn')    | Should -BeFalse
        }
    }

    Context 'Skip when fixture absent' -Skip:$global:MtZtaJsonExportFixtureExists {
        It 'placeholder so this Context emits a row when fixture is missing' {
            Set-ItResult -Skipped -Because 'Captured tenant export not present on this checkout.'
        }
    }
}
