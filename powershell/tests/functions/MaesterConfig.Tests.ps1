Describe 'Maester Configuration File - tests/maester-config.json' {
    Context 'TestSettings array' {
        It 'should be sorted by Id' {
            # Correctly join paths to find the repo root and config file
            $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
            $configPath = Join-Path $repoRoot 'tests/maester-config.json'
            $configJson = Get-Content -Path $configPath -Raw | ConvertFrom-Json

            $testSettings = $configJson.TestSettings
            if ($null -ne $testSettings -and $testSettings.Count -gt 1) {
                $originalIds = $testSettings.Id
                $sortedIds = $testSettings.Id | Sort-Object

                $originalIds | Should -BeExactly $sortedIds -Because 'TestSettings in maester-config.json should be sorted by Id of the test for better diffs, history, and easier maintenance.'
            } else {
                Write-Warning "Skipping sort test as TestSettings array is null, empty, or has only one item in $configPath"
            }
        }
    }
}
