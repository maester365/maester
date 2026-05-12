# Unit tests for Test-MtZtaFreshness.
# The function is internal (auto-loaded via Maester.psm1); tests call it inside
# the module scope via `& $module { ... }`.

Describe 'Test-MtZtaFreshness' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'
    }

    Context 'Timestamp source priority' {

        BeforeEach {
            $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-fresh-$([guid]::NewGuid())")
            New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
        }

        AfterEach {
            if (Test-Path $script:bundle) { Remove-Item -Recurse -Force $script:bundle }
        }

        It 'prefers manifest.runStartTime over report.ExecutedAt and DB mtime' {
            # Three signals point at three different ages; manifest must win.
            @{
                schemaVersion = '1.0'
                tenantId      = '00000000-0000-0000-0000-000000000000'
                runStartTime  = (Get-Date).ToUniversalTime().AddDays(-3).ToString('o')
            } | ConvertTo-Json | Set-Content (Join-Path $script:bundle 'manifest.json')
            @{ ExecutedAt = (Get-Date).ToUniversalTime().AddDays(-30).ToString('o'); Tests = @() } |
                ConvertTo-Json | Set-Content (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
            New-Item -ItemType Directory -Force -Path (Join-Path $script:bundle 'db') | Out-Null
            $oldDate = (Get-Date).ToUniversalTime().AddDays(-60)
            $dbFile  = Join-Path $script:bundle 'db/zt.db'
            New-Item -ItemType File -Path $dbFile | Out-Null
            (Get-Item $dbFile).LastWriteTimeUtc = $oldDate

            $result = & $script:mod { param($p) Test-MtZtaFreshness -BundlePath $p } $script:bundle

            $result.TimestampSource | Should -Be 'ManifestRunStartTime'
            $result.AgeDays         | Should -Be 3
            $result.IsStale         | Should -BeFalse  # under default 14-day threshold
        }

        It 'falls back to report.ExecutedAt when manifest is absent' {
            @{ ExecutedAt = (Get-Date).ToUniversalTime().AddDays(-7).ToString('o'); Tests = @() } |
                ConvertTo-Json | Set-Content (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')

            $result = & $script:mod { param($p) Test-MtZtaFreshness -BundlePath $p } $script:bundle

            $result.TimestampSource | Should -Be 'JsonExecutedAt'
            $result.AgeDays         | Should -Be 7
            $result.IsStale         | Should -BeFalse
        }

        It 'falls back to DB mtime when manifest and report timestamps are unavailable' {
            New-Item -ItemType Directory -Force -Path (Join-Path $script:bundle 'db') | Out-Null
            $dbFile = Join-Path $script:bundle 'db/zt.db'
            New-Item -ItemType File -Path $dbFile | Out-Null
            $age = (Get-Date).ToUniversalTime().AddDays(-21)
            (Get-Item $dbFile).LastWriteTimeUtc = $age

            # No manifest, no report — only the DB exists.
            $result = & $script:mod { param($p) Test-MtZtaFreshness -BundlePath $p -WarningAction SilentlyContinue } $script:bundle

            $result.TimestampSource | Should -Be 'DbMtime'
            $result.AgeDays         | Should -Be 21
            $result.IsStale         | Should -BeTrue   # exceeds default 14-day threshold
        }

        It 'returns IsStale=$false with TimestampSource=None when nothing is parseable' {
            # Empty bundle: no manifest, no report, no DB.
            $result = & $script:mod { param($p) Test-MtZtaFreshness -BundlePath $p -WarningAction SilentlyContinue } $script:bundle

            $result.TimestampSource | Should -Be 'None'
            $result.AgeDays         | Should -Be -1
            $result.IsStale         | Should -BeFalse
        }
    }

    Context 'Threshold honored' {

        BeforeEach {
            $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-fresh-$([guid]::NewGuid())")
            New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
        }

        AfterEach {
            if (Test-Path $script:bundle) { Remove-Item -Recurse -Force $script:bundle }
        }

        It 'flips IsStale=$true once age exceeds custom threshold' {
            @{
                schemaVersion = '1.0'
                runStartTime  = (Get-Date).ToUniversalTime().AddDays(-5).ToString('o')
            } | ConvertTo-Json | Set-Content (Join-Path $script:bundle 'manifest.json')

            $tight  = & $script:mod { param($p) Test-MtZtaFreshness -BundlePath $p -FreshnessDays 3 } $script:bundle
            $loose  = & $script:mod { param($p) Test-MtZtaFreshness -BundlePath $p -FreshnessDays 30 } $script:bundle

            $tight.IsStale | Should -BeTrue
            $tight.Threshold | Should -Be 3
            $loose.IsStale | Should -BeFalse
            $loose.Threshold | Should -Be 30
        }

        It 'clamps a future-dated timestamp to AgeDays=0 (clock skew / timezone slop)' {
            # ZTA bundles produced on a host whose clock is a few minutes / hours
            # ahead of the runner produce timestamps "in the future". Floor() of a
            # negative TotalDays returns -1, which downstream renderers turn into
            # "-1d" and a "-7%" chip. Clamp to 0 so the report shows "fresh".
            @{
                schemaVersion = '1.0'
                runStartTime  = (Get-Date).ToUniversalTime().AddHours(1).ToString('o')
            } | ConvertTo-Json | Set-Content (Join-Path $script:bundle 'manifest.json')

            $r = & $script:mod { param($p) Test-MtZtaFreshness -BundlePath $p } $script:bundle

            $r.AgeDays | Should -Be 0
            $r.IsStale | Should -BeFalse
            $r.TimestampSource | Should -Be 'ManifestRunStartTime'
        }
    }

    Context 'Error surface' {
        It 'throws when -BundlePath does not exist' {
            $bogus = Join-Path ([System.IO.Path]::GetTempPath()) "nonexistent-$([guid]::NewGuid())"
            { & $script:mod { param($p) Test-MtZtaFreshness -BundlePath $p } $bogus } | Should -Throw -ExpectedMessage '*bundle path not found*'
        }
    }
}
