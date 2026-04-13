Describe 'Import-MtMaesterResult' {
    BeforeAll {
        # Create a temp directory for test JSON files
        $testDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "MaesterImportTests_$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null

        # Single-tenant result object
        $singleTenantData = [PSCustomObject]@{
            TenantId       = 'tenant-1-id'
            TenantName     = 'Tenant One'
            Result         = 'Passed'
            TotalCount     = 10
            PassedCount    = 8
            FailedCount    = 2
            ErrorCount     = 0
            SkippedCount   = 0
            InvestigateCount = 0
            NotRunCount    = 0
            ExecutedAt     = '2026-04-01T10:00:00'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Id = 'MT.1001'; Result = 'Passed'; Block = 'Maester' }
                [PSCustomObject]@{ Id = 'MT.1002'; Result = 'Failed'; Block = 'Maester' }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 8; FailedCount = 2; TotalCount = 10 }
            )
            EndOfJson      = 'EndOfJson'
        }

        $singleTenantData2 = [PSCustomObject]@{
            TenantId       = 'tenant-2-id'
            TenantName     = 'Tenant Two'
            Result         = 'Failed'
            TotalCount     = 5
            PassedCount    = 3
            FailedCount    = 2
            ErrorCount     = 0
            SkippedCount   = 0
            InvestigateCount = 0
            NotRunCount    = 0
            ExecutedAt     = '2026-04-01T11:00:00'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Id = 'MT.1001'; Result = 'Failed'; Block = 'Maester' }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 3; FailedCount = 2; TotalCount = 5 }
            )
            EndOfJson      = 'EndOfJson'
        }

        # Multi-tenant merged format
        $mergedData = [PSCustomObject]@{
            Tenants        = @($singleTenantData, $singleTenantData2)
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            EndOfJson      = 'EndOfJson'
        }

        # Write test files
        $file1 = Join-Path $testDir 'TestResults-2026-04-01-100000.json'
        $singleTenantData | ConvertTo-Json -Depth 5 | Out-File -FilePath $file1 -Encoding UTF8

        $file2 = Join-Path $testDir 'TestResults-2026-04-01-110000.json'
        $singleTenantData2 | ConvertTo-Json -Depth 5 | Out-File -FilePath $file2 -Encoding UTF8

        $mergedFile = Join-Path $testDir 'merged-results.json'
        $mergedData | ConvertTo-Json -Depth 7 | Out-File -FilePath $mergedFile -Encoding UTF8

        # Write an invalid JSON file
        $invalidFile = Join-Path $testDir 'invalid.json'
        '{ "NotAResult": true }' | Out-File -FilePath $invalidFile -Encoding UTF8

        # Write a malformed file
        $malformedFile = Join-Path $testDir 'malformed.json'
        'this is not json at all' | Out-File -FilePath $malformedFile -Encoding UTF8

        # Create a subdirectory with results (for directory discovery)
        $subDir = Join-Path $testDir 'sub-results'
        New-Item -Path $subDir -ItemType Directory -Force | Out-Null
        $singleTenantData | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $subDir 'TestResults-2026-04-01-100000.json') -Encoding UTF8

        # Create a custom-named file (not matching TestResults-* pattern)
        $customFile = Join-Path $testDir 'production.json'
        $singleTenantData | ConvertTo-Json -Depth 5 | Out-File -FilePath $customFile -Encoding UTF8
    }

    AfterAll {
        # Clean up temp directory
        if (Test-Path $testDir) {
            Remove-Item -Path $testDir -Recurse -Force
        }
    }

    Context 'Loading single-tenant JSON files' {
        It 'Should load a single file by path' {
            $results = Import-MtMaesterResult -Path $file1

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeExactly 1
            $results[0].TenantId | Should -BeExactly 'tenant-1-id'
            $results[0].TenantName | Should -BeExactly 'Tenant One'
        }

        It 'Should load multiple files by path' {
            $results = Import-MtMaesterResult -Path $file1, $file2

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeExactly 2
            $results[0].TenantId | Should -BeExactly 'tenant-1-id'
            $results[1].TenantId | Should -BeExactly 'tenant-2-id'
        }

        It 'Should preserve all properties on loaded results' {
            $results = Import-MtMaesterResult -Path $file1

            $results[0].Tests.Count | Should -BeExactly 2
            $results[0].TotalCount | Should -BeExactly 10
            $results[0].ExecutedAt | Should -Not -BeNullOrEmpty
            $results[0].CurrentVersion | Should -BeExactly '2.0.0'
        }
    }

    Context 'Loading multi-tenant merged JSON' {
        It 'Should auto-expand a merged file into individual tenant results' {
            $results = Import-MtMaesterResult -Path $mergedFile

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeExactly 2
            $results[0].TenantId | Should -BeExactly 'tenant-1-id'
            $results[1].TenantId | Should -BeExactly 'tenant-2-id'
        }

        It 'Should treat expanded tenants as standalone results' {
            $results = Import-MtMaesterResult -Path $mergedFile

            $results[0].Tests | Should -Not -BeNullOrEmpty
            $results[1].Tests | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Directory discovery' {
        It 'Should discover TestResults-*.json files in a directory' {
            $results = Import-MtMaesterResult -Path $subDir

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeExactly 1
            $results[0].TenantId | Should -BeExactly 'tenant-1-id'
        }

        It 'Should fall back to all *.json files when no TestResults-* files exist' {
            # Create a directory with only custom-named JSON files
            $customDir = Join-Path $testDir 'custom-names'
            New-Item -Path $customDir -ItemType Directory -Force | Out-Null
            $singleTenantData | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $customDir 'production.json') -Encoding UTF8
            $singleTenantData2 | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $customDir 'development.json') -Encoding UTF8

            $results = Import-MtMaesterResult -Path $customDir

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeExactly 2
        }
    }

    Context 'Glob patterns' {
        It 'Should resolve glob patterns for file paths' {
            $globPattern = Join-Path $testDir 'TestResults-*.json'
            $results = Import-MtMaesterResult -Path $globPattern

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeExactly 2
        }
    }

    Context 'Validation and error handling' {
        It 'Should skip files missing required properties with a warning' {
            $results = Import-MtMaesterResult -Path $invalidFile -WarningAction SilentlyContinue

            $results.Count | Should -BeExactly 0
        }

        It 'Should skip malformed JSON files with a warning' {
            $results = Import-MtMaesterResult -Path $malformedFile -WarningAction SilentlyContinue

            $results.Count | Should -BeExactly 0
        }

        It 'Should emit an error for nonexistent paths' {
            { Import-MtMaesterResult -Path './nonexistent/path/file.json' -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Pipeline input' {
        It 'Should accept pipeline input from strings' {
            $results = @($file1, $file2) | Import-MtMaesterResult

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeExactly 2
        }

        It 'Should accept pipeline input from Get-ChildItem via FullName alias' {
            $results = Get-ChildItem -Path $testDir -Filter 'TestResults-*.json' | Import-MtMaesterResult

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeExactly 2
        }
    }

    Context 'Integration with Merge-MtMaesterResult' {
        It 'Should pipe directly into Merge-MtMaesterResult' {
            $merged = Import-MtMaesterResult -Path $file1, $file2 | Merge-MtMaesterResult

            $merged | Should -Not -BeNullOrEmpty
            $merged.Tenants | Should -Not -BeNullOrEmpty
            $merged.Tenants.Count | Should -BeExactly 2
            $merged.EndOfJson | Should -BeExactly 'EndOfJson'
        }
    }
}
