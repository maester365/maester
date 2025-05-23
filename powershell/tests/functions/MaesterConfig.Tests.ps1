Describe 'Maester Configuration File - tests/maester-config.json' {
    Context 'TestSettings array' {
        It 'should be sorted by Id' {
            # Correctly join paths to find the repo root and config file
            $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
            $configPath = Join-Path $repoRoot 'tests/maester-config.json'
            $configJson = Get-Content -Path $configPath -Raw | ConvertFrom-Json

            $testSettings = $configJson.TestSettings
            if ($null -ne $testSettings -and $testSettings.Count -gt 1) {

                # figure out maximum number of dot-segments any Id has
                $maxSeg = ($testSettings | ForEach-Object { ($_.Id -split '\.').Count } |
                    Measure-Object -Maximum).Maximum

                # sort by building a padded string key for each Id
                $sortedTestSettings = $testSettings | Sort-Object -Property @{Expression = {
                  $parts = $_.Id -split '\.'
                  0..($maxSeg-1) | ForEach-Object {
                    if ($_ -lt $parts.Count -and $parts[$_] -match '^\d+$') {
                      # pad numbers to 5 digits (adjust width if you have bigger numbers)
                      $parts[$_].PadLeft(5, '0')
                    }
                    elseif ($_ -lt $parts.Count) {
                      # non-numeric segment (prefix)
                      $parts[$_]
                    }
                    else {
                      # missing segment => pad zeros
                      ''.PadLeft(5, '0')
                    }
                  }
                }}

                # Find  the first incorrect Id by comparing the original and sorted Ids
                $isSorted = $true
                for ($i = 0; $i -lt $originalIds.Count; $i++) {
                    if ($testSettings[$i].Id -ne $sortedTestSettings[$i].Id) {
                        $isSorted = $false
                        $expected = $sortedTestSettings[$i].Id
                        $actual = $testSettings[$i].Id
                        break
                    }
                }

                $isSorted | Should -BeTrue -Because "TestId: Expected='$expected' Actual: '$actual' ❌ is not sorted in maester-config.json. The Test IDs should be sorted for better diffs, history, and easier maintenance."

            } else {
                Write-Warning "Skipping sort test as TestSettings array is null, empty, or has only one item in $configPath"
            }
        }
    }
}
