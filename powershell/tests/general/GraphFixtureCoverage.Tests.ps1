# Every Microsoft Graph test ships with mock data: a Graph fixture set (scenario) under
# powershell/tests/fixtures/graph-replay in which it passes, and one in which it fails, declared in the
# scenarios' scenario.json "expectations". GraphFixtureScenarios.Tests.ps1 runs them. See
# website/docs/writing-tests/graph-fixtures.md.
#
# The tests that had no mock data when the rule came in are listed in coverage-baseline.txt. The list only
# shrinks: a test that gets mock data must leave it, and a new test can never join it. On a pull request
# (MAESTER_FIXTURE_BASE_REF set by the build-validation workflow) a test the pull request changes must leave it too.
BeforeDiscovery {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
}

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:FixtureRoot = Join-Path $script:RepoRoot 'powershell/tests/fixtures/graph-replay'
    $script:BaselineFile = Join-Path $script:FixtureRoot 'coverage-baseline.txt'

    $script:Catalog = @(InModuleScope Maester { Get-MtTestCatalog })
    $script:CatalogById = @{}
    foreach ($t in $script:Catalog) { $script:CatalogById[$t.Id] = $t }

    # The rule covers the tests that read Microsoft Graph only. Tests of other services cannot be replayed yet,
    # and the generated suites (EIDSCA, ORCA) are written by their generators, not by a contributor.
    $script:InScope = @($script:Catalog | Where-Object {
            (@($_.Service) -join '+') -eq 'Graph' -and $_.Suite -notin 'EIDSCA', 'ORCA'
        } | ForEach-Object Id)

    # Expected results by test: ID -> list of results across the scenarios.
    $script:Expected = @{}
    $script:Scenarios = @(Get-ChildItem -Path $script:FixtureRoot -Filter 'scenario.json' -Recurse -File | ForEach-Object {
            $scenario = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            foreach ($expectation in @($scenario.expectations.PSObject.Properties)) {
                if (-not $script:Expected.ContainsKey($expectation.Name)) { $script:Expected[$expectation.Name] = [System.Collections.Generic.List[string]]::new() }
                $script:Expected[$expectation.Name].Add([string]$expectation.Value)
            }
            [pscustomobject]@{ Name = $_.Directory.Name; File = $_.FullName; Data = $scenario }
        })

    function script:Test-Covered {
        param([string] $Id)
        $results = $script:Expected[$Id]
        if ($results -and $results -contains 'Passed' -and $results -contains 'Failed') { return $true }
        # A shim returns the result of the test it calls, so that test's mock data covers it.
        $test = $script:CatalogById[$Id]
        if ($test -and $test.ShimOf -and $test.ShimOf -ne $Id) { return (Test-Covered -Id $test.ShimOf) }
        return $false
    }

    $script:Baseline = @(Get-Content -LiteralPath $script:BaselineFile | Where-Object { $_ -and $_ -notmatch '^\s*#' } | ForEach-Object { $_.Trim() })
}

Describe 'Mock data for every Graph test' {
    It 'every Graph test that is not in the baseline has mock data with a passing and a failing case' {
        $offenders = @($script:InScope | Where-Object { $_ -notin $script:Baseline -and -not (Test-Covered -Id $_) } | Sort-Object)
        $offenders | Should -BeNullOrEmpty -Because (
            'a new or changed test ships with mock data: add fixtures to a scenario in which it passes and one in which it fails, ' +
            'and list it in the expectations of their scenario.json (website/docs/writing-tests/graph-fixtures.md). Missing for: ' + ($offenders -join ', '))
    }

    It 'the baseline lists only tests that still have no mock data' {
        $covered = @($script:Baseline | Where-Object { Test-Covered -Id $_ })
        $covered | Should -BeNullOrEmpty -Because "these tests have mock data now: remove them from $($script:BaselineFile): $($covered -join ', ')"
        $stale = @($script:Baseline | Where-Object { $_ -notin $script:InScope })
        $stale | Should -BeNullOrEmpty -Because "these tests no longer exist or no longer read only Graph: remove them from the baseline: $($stale -join ', ')"
        [string[]] $sorted = @($script:Baseline)
        [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
        ($script:Baseline -join "`n") | Should -BeExactly ($sorted -join "`n") -Because 'the baseline is kept sorted so a change to it is easy to review'
    }

    It 'a test that the pull request changes leaves the baseline' -Skip:(-not $env:MAESTER_FIXTURE_BASE_REF) {
        $baseRef = $env:MAESTER_FIXTURE_BASE_REF
        $changed = @(git -C $script:RepoRoot diff --name-only $baseRef HEAD -- 'tests/' 2>$null | Where-Object { $_ -match '/Test\.(?<id>.+)\.(ps1|md)$' } | ForEach-Object {
                [regex]::Match($_, '/Test\.(?<id>.+)\.(ps1|md)$').Groups['id'].Value
            } | Select-Object -Unique)
        $LASTEXITCODE | Should -Be 0 -Because "git could not compare with $baseRef; the workflow fetches it before the tests run"
        $offenders = @($changed | Where-Object { $_ -in $script:Baseline })
        $offenders | Should -BeNullOrEmpty -Because (
            'a changed test ships with mock data like a new one: add its passing and failing fixtures and remove it from the baseline: ' + ($offenders -join ', '))
    }
}

Describe 'Graph fixture sets' {
    It 'every expectation names a test that exists and a result a test can have' {
        $problems = foreach ($scenario in $script:Scenarios) {
            foreach ($expectation in @($scenario.Data.expectations.PSObject.Properties)) {
                if (-not $script:CatalogById.ContainsKey($expectation.Name)) { "$($scenario.Name): $($expectation.Name) is not a test" }
                if ([string]$expectation.Value -notin 'Passed', 'Failed', 'Skipped', 'Investigate', 'Error') { "$($scenario.Name): $($expectation.Name) expects '$($expectation.Value)'" }
            }
        }
        @($problems) | Should -BeNullOrEmpty
    }

    It 'holds no real tenant data: every GUID is a fake one or one Maester itself uses' {
        $wellKnown = InModuleScope Maester { Get-MtGraphFixtureWellKnownId }
        $pattern = '(?<![0-9A-Fa-f])[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(?![0-9A-Fa-f])'
        $offenders = foreach ($file in Get-ChildItem -Path $script:FixtureRoot -Filter '*.json' -Recurse -File) {
            foreach ($match in [regex]::Matches([System.IO.File]::ReadAllText($file.FullName), $pattern)) {
                if ($match.Value -notmatch '^fa4efa4e-' -and -not $wellKnown.Contains($match.Value)) { "$($file.Name): $($match.Value)" }
            }
        }
        @($offenders) | Should -BeNullOrEmpty -Because 'fixtures are hand-written with fake IDs (fa4efa4e-...) or recorded with sanitisation on'
    }

    It 'holds no sanitisation salt' {
        @(Get-ChildItem -Path $script:FixtureRoot -Filter '.salt' -Recurse -File -Force) | Should -BeNullOrEmpty -Because 'the salt of a recording stays on the computer that recorded it'
    }
}
