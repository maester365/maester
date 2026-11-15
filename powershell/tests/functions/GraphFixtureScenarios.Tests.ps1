# Runs each test that has mock data against each Graph fixture set (scenario) under fixtures/graph-replay, in replay
# mode, and checks the result its scenario.json expects. No connection and no network: this is how a test's passing
# and failing cases are kept working. See website/docs/writing-tests/graph-fixtures.md.
BeforeDiscovery {
    $script:FixtureRoot = Join-Path $PSScriptRoot '../fixtures/graph-replay'
    $script:Cases = foreach ($file in Get-ChildItem -Path $script:FixtureRoot -Filter 'scenario.json' -Recurse -File) {
        $scenario = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        foreach ($expectation in @($scenario.expectations.PSObject.Properties)) {
            @{ Scenario = $file.Directory.Name; Id = $expectation.Name; Expected = [string]$expectation.Value }
        }
    }
    $script:Scenarios = @(Get-ChildItem -Path $script:FixtureRoot -Directory | ForEach-Object { @{ Scenario = $_.Name } })
}

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    $script:FixtureRoot = (Resolve-Path (Join-Path $PSScriptRoot '../fixtures/graph-replay')).Path
}

AfterAll {
    $null = Disable-MtGraphFixture
}

Describe 'Mock data of the tests' {
    BeforeEach {
        Push-Location $TestDrive
    }

    AfterEach {
        $null = Disable-MtGraphFixture
        Pop-Location
    }

    It '<Id> is <Expected> in the <Scenario> fixture set' -ForEach $script:Cases {
        $null = Enable-MtGraphFixture -Mode Replay -Path $script:FixtureRoot -Scenario $Scenario
        $rows = @(Invoke-MtTest -Id $Id -Config @{} -WarningAction SilentlyContinue)
        $status = Get-MtGraphFixtureStatus

        $missing = @($status.Missing | ForEach-Object { "$($_.Key) ($($_.File))" }) -join '; '
        $status.MissingCount | Should -Be 0 -Because "every request the test makes needs a fixture in $Scenario. Missing: $missing"
        $rows.Count | Should -Be 1
        $rows[0].Result | Should -Be $Expected -Because "the $Scenario fixture set should make $Id $Expected. The test said: $($rows[0].ReasonDetail)"
    }
}

Describe 'Graph fixture sets' {
    It 'the index of <Scenario> lists its fixtures and every file is named after its request' -ForEach $script:Scenarios {
        $copy = Join-Path $TestDrive $Scenario
        Copy-Item -LiteralPath (Join-Path $script:FixtureRoot $Scenario) -Destination $copy -Recurse
        $result = Update-MtGraphFixtureIndex -Path $TestDrive -Scenario $Scenario -ErrorAction SilentlyContinue
        $result.Problems | Should -BeNullOrEmpty
        $expected = Get-Content -LiteralPath (Join-Path $copy 'index.json') -Raw
        $actual = Get-Content -LiteralPath (Join-Path $script:FixtureRoot "$Scenario/index.json") -Raw
        $actual | Should -BeExactly $expected -Because "index.json is out of date. Run: Update-MtGraphFixtureIndex -Path ./powershell/tests/fixtures/graph-replay -Scenario $Scenario"
    }
}
