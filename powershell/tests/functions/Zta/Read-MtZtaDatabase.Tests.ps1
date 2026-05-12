# Unit tests for Read-MtZtaDatabase.
# DuckDB.NET.Data.dll is NOT bundled with the upstream Maester repo. Tests verify
# parameter validation + the missing-binary error path and schema baseline list.
# Real DuckDB integration tests are gated behind an availability check — they only
# run when DuckDB binaries are accessible on the current machine.

BeforeDiscovery {
    # Pester evaluates -Skip: at Discovery time (before any BeforeAll).
    # duckDbAvailable must cover ALL probe paths Initialize-MtZtaDuckDbAssembly uses
    # (AppDomain, ZTA module lib/, Maester lib/). Checking only Maester's lib/ would
    # mis-classify machines where ZeroTrustAssessment is installed: the "absent" path
    # would assume $null but Initialize would actually succeed, causing a real DuckDB
    # IO error on the bogus .db file instead of a $null return.
    $modulePath = Resolve-Path "$PSScriptRoot/../../../Maester.psd1" | Select-Object -ExpandProperty Path
    $moduleRoot = Split-Path $modulePath -Parent

    $duckDbInMaesterLib = Test-Path (Join-Path $moduleRoot 'lib/DuckDB.NET.Data.dll')

    $duckDbInAppDomain = [bool]([System.AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'DuckDB.NET.Data' } | Select-Object -First 1)

    $duckDbInZtaModule = $false
    $ztaMod = Get-Module -ListAvailable ZeroTrustAssessment -ErrorAction SilentlyContinue |
              Sort-Object Version -Descending | Select-Object -First 1
    if ($ztaMod) {
        $duckDbInZtaModule = Test-Path (Join-Path $ztaMod.ModuleBase 'lib/DuckDB.NET.Data.dll')
    }

    $script:duckDbAvailable = $duckDbInMaesterLib -or $duckDbInAppDomain -or $duckDbInZtaModule
    $script:sampleDbPath    = Join-Path $PSScriptRoot 'fixtures/zt.sample.db'
    $script:sampleDbExists  = (Test-Path $script:sampleDbPath)
}

Describe 'Read-MtZtaDatabase (PR-C)' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
    }

    Context 'Surface and parameter validation' {

        It 'throws when -DatabasePath does not exist' {
            $bogus = Join-Path ([System.IO.Path]::GetTempPath()) "no-zt-$([guid]::NewGuid()).db"
            { & $script:mod { param($p) Read-MtZtaDatabase -DatabasePath $p } $bogus } |
                Should -Throw -ExpectedMessage '*database file not found*'
        }
    }

    Context 'DuckDB binaries not installed (default state)' -Skip:$duckDbAvailable {

        # Returns $null (not throws) when no DuckDB assembly can be located;
        # callers treat DuckDB as opportunistic and fall back to JSON-shadow.
        It 'returns $null when no DuckDB.NET.Data assembly can be located' {
            $f = New-TemporaryFile
            $fakeDb = $f.FullName + '.db'
            Move-Item $f.FullName $fakeDb
            try {
                $result = & $script:mod { param($p) Read-MtZtaDatabase -DatabasePath $p } $fakeDb
                $result | Should -BeNullOrEmpty
            }
            finally { Remove-Item $fakeDb -Force -ErrorAction SilentlyContinue }
        }
    }

    Context 'DuckDB binaries installed (operator populated lib/)' -Skip:(-not $duckDbAvailable) {

        It 'returns a context object with Connection / Query / Tables / Dispose when the .db opens' -Skip:(-not $sampleDbExists) {
            $ctx = & $script:mod { param($p) Read-MtZtaDatabase -DatabasePath $p } $sampleDbPath
            try {
                $ctx                  | Should -Not -BeNullOrEmpty
                $ctx.Connection       | Should -Not -BeNullOrEmpty
                $ctx.Query            | Should -Not -BeNullOrEmpty
                $ctx.Tables           | Should -Not -BeNullOrEmpty
                $ctx.Tables.Count     | Should -BeGreaterThan 0
            }
            finally {
                if ($ctx -and $ctx.Dispose) { & $ctx.Dispose }
            }
        }
    }
}
