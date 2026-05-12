# Integration tests for Import-MtZtaResult end-to-end + the public surface guarantees.
# All tests use -ForceJsonFallback so they don't depend on DuckDB binaries.
# The DuckDB read path is tested separately in Read-MtZtaDatabase.Tests.ps1.

Describe 'ZTA module surface + Import-MtZtaResult' -Tag 'Acceptance', 'Zta' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'
    }

    Context 'Module exports the four new public cmdlets' {
        BeforeAll {
            $script:exported = Get-Command -Module Maester -CommandType Function | Select-Object -ExpandProperty Name
            $script:exportedAliases = Get-Command -Module Maester -CommandType Alias | Select-Object -ExpandProperty Name
        }
        It 'exports Import-MtZtaResult (singular per PSUseSingularNouns)' { $script:exported | Should -Contain 'Import-MtZtaResult' }
        It 'exports the back-compat alias Import-MtZtaResults' { $script:exportedAliases | Should -Contain 'Import-MtZtaResults' }
        It 'exports Get-MtZta' { $script:exported | Should -Contain 'Get-MtZta' }
        It 'exports Get-MtZtaRecommendedTag' { $script:exported | Should -Contain 'Get-MtZtaRecommendedTag' }
        It 'exports Update-MtSeverityFromZta' { $script:exported | Should -Contain 'Update-MtSeverityFromZta' }
    }

    Context 'Public-stub guards (no $script:MtZtaContext)' {
        BeforeAll {
            # Force a clean state — no prior load.
            & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        }

        It 'Import-MtZtaResult no-ops when -ZtaResultsPath is empty' {
            { Import-MtZtaResult -ZtaResultsPath '' -ErrorAction Stop } | Should -Not -Throw
            (Get-MtZta) | Should -BeNullOrEmpty
        }
        It 'Get-MtZta returns $null when context is not set' {
            Get-MtZta | Should -BeNullOrEmpty
        }
        It 'Get-MtZtaRecommendedTag returns empty array when context is not set' {
            $tags = @(Get-MtZtaRecommendedTag)
            $tags.Count | Should -Be 0
        }
        It 'Update-MtSeverityFromZta returns input unchanged when context is not set' {
            $tsArray = @( @{ Id = 'X.1'; Severity = 'Medium' } )
            $out = @(Update-MtSeverityFromZta -TestSettings $tsArray -WhatIf:$false)
            $out.Count | Should -Be 1
            $out[0].Severity | Should -Be 'Medium'
        }
    }

    Context 'Sample fixture loads cleanly' {
        It 'fixture file exists' {
            (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') | Should -Exist
        }
        It 'parses as JSON with the expected top-level shape' {
            $obj = Get-Content (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') -Raw | ConvertFrom-Json
            $obj.TenantId   | Should -Not -BeNullOrEmpty
            $obj.ExecutedAt | Should -Not -BeNullOrEmpty
            $obj.Tests      | Should -Not -BeNullOrEmpty
            $obj.EndOfJson  | Should -BeTrue
        }
        It 'covers all four ZTA pillars' {
            $obj = Get-Content (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') -Raw | ConvertFrom-Json
            $pillars = $obj.Tests | Select-Object -ExpandProperty TestPillar | Sort-Object -Unique
            'Identity','Devices','Network','Data' | ForEach-Object { $pillars | Should -Contain $_ }
        }
    }

    Context 'Import-MtZtaResult — local-folder integration (-ForceJsonFallback)' {

        BeforeEach {
            # Fresh bundle per test — copy the sanitised fixtures into a temp directory.
            $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-import-$([guid]::NewGuid())")
            New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
            Copy-Item (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
            Copy-Item (Join-Path $script:fixtureDir 'manifest.sample.json') (Join-Path $script:bundle 'manifest.json')

            # Reset the module-private context.
            & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        }

        AfterEach {
            if (Test-Path $script:bundle) { Remove-Item -Recurse -Force $script:bundle }
            & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        }

        It 'populates MtZtaContext with manifest + tests + freshness' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback

            $ctx = Get-MtZta
            $ctx              | Should -Not -BeNullOrEmpty
            $ctx.TenantId     | Should -Be '00000000-0000-0000-0000-000000000000'
            $ctx.TenantName   | Should -Be 'Sample Tenant'
            $ctx.Tests.Count  | Should -Be 5
            $ctx.Manifest     | Should -Not -BeNullOrEmpty
            $ctx.Manifest.schemaVersion | Should -Be '1.0'
            $ctx.Database     | Should -BeNullOrEmpty   # ForceJsonFallback skips DuckDB
            $ctx.DatabaseStatus | Should -Be 'ForcedJsonFallback'
            $ctx.Freshness    | Should -Not -BeNullOrEmpty
            $ctx.Freshness.TimestampSource | Should -Be 'ManifestRunStartTime'
        }

        It 'is idempotent — second call with the same source short-circuits' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $first = Get-MtZta
            $firstLoadedAt = $first.LoadedAt

            Start-Sleep -Milliseconds 50
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $second = Get-MtZta

            $second.LoadedAt | Should -Be $firstLoadedAt
        }

        It 'Get-MtZta -Section Tests returns the raw Tests[] array' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $tests = Get-MtZta -Section Tests
            $tests.Count | Should -Be 5
            ($tests | Where-Object TestPillar -eq 'Identity').Count | Should -BeGreaterThan 0
        }

        It 'Get-MtZta -Section Manifest returns the manifest object' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $m = Get-MtZta -Section Manifest
            $m.tenantId        | Should -Be '00000000-0000-0000-0000-000000000000'
            $m.ztaVersion      | Should -Be '2.2.0'
            $m.pillarsCovered.Count | Should -Be 4
        }

        It 'Get-MtZta -Section Database returns $null when ForceJsonFallback was used' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            Get-MtZta -Section Database | Should -BeNullOrEmpty
        }

        It 'rejects load when -ExpectedTenantId mismatches the manifest' {
            { Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback `
                                  -ExpectedTenantId 'ffffffff-ffff-ffff-ffff-ffffffffffff' } |
                Should -Throw -ExpectedMessage '*tenant mismatch*'
        }

        It 'allows load when -ExpectedTenantId matches the manifest' {
            { Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback `
                                  -ExpectedTenantId '00000000-0000-0000-0000-000000000000' } |
                Should -Not -Throw
        }

        It 'flags the bundle as stale when the manifest timestamp is older than -FreshnessDays' {
            # Override the manifest to be 100 days old.
            @{
                schemaVersion = '1.0'
                tenantId      = '00000000-0000-0000-0000-000000000000'
                runStartTime  = (Get-Date).ToUniversalTime().AddDays(-100).ToString('o')
                ztaVersion    = '2.2.0'
            } | ConvertTo-Json | Set-Content (Join-Path $script:bundle 'manifest.json')

            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -WarningAction SilentlyContinue

            $ctx = Get-MtZta
            $ctx.IsStale       | Should -BeTrue
            $ctx.Freshness.AgeDays | Should -BeGreaterThan 14
        }

        It 'throws when the bundle is missing ZeroTrustAssessmentReport.json' {
            Remove-Item (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
            { Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback } |
                Should -Throw -ExpectedMessage '*missing ZeroTrustAssessmentReport.json*'
        }
    }

    Context 'Backward-compat: vanilla Maester is unchanged when ZTA is absent' {

        BeforeAll {
            & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        }

        It 'Get-MtZta returns $null with no warnings when no ZTA was loaded' {
            (Get-MtZta) | Should -BeNullOrEmpty
        }

        It 'Import-MtZtaResult with $null does not populate any context' {
            Import-MtZtaResult -ZtaResultsPath $null
            (Get-MtZta) | Should -BeNullOrEmpty
        }
    }
}
