Describe 'Merge-MtMaesterResult' {
    BeforeAll {
        $tenant1 = [PSCustomObject]@{
            TenantId       = 'tenant-1-id'
            TenantName     = 'Tenant One'
            Result         = 'Passed'
            TotalCount     = 10
            PassedCount    = 8
            FailedCount    = 2
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

        $tenant2 = [PSCustomObject]@{
            TenantId       = 'tenant-2-id'
            TenantName     = 'Tenant Two'
            Result         = 'Failed'
            TotalCount     = 5
            PassedCount    = 3
            FailedCount    = 2
            ExecutedAt     = '2026-04-01T11:00:00'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Id = 'MT.1001'; Result = 'Failed'; Block = 'Maester' }
                [PSCustomObject]@{ Id = 'MT.1002'; Result = 'Passed'; Block = 'Maester' }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 3; FailedCount = 2; TotalCount = 5 }
            )
            EndOfJson      = 'EndOfJson'
        }

        # Create temp directory with JSON files for -Path tests
        $testDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "MaesterMergeTests_$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null

        $file1 = Join-Path $testDir 'TestResults-2026-04-01-100000.json'
        $tenant1 | ConvertTo-Json -Depth 5 | Out-File -FilePath $file1 -Encoding UTF8

        $file2 = Join-Path $testDir 'TestResults-2026-04-01-110000.json'
        $tenant2 | ConvertTo-Json -Depth 5 | Out-File -FilePath $file2 -Encoding UTF8
    }

    AfterAll {
        if (Test-Path $testDir) {
            Remove-Item -Path $testDir -Recurse -Force
        }
    }

    It 'Should throw when no results are provided' {
        { Merge-MtMaesterResult -MaesterResults @() } | Should -Throw
    }

    It 'Should wrap a single result in Tenants array' {
        $result = Merge-MtMaesterResult -MaesterResults @($tenant1)

        $result.Tenants | Should -Not -BeNullOrEmpty -Because 'single results should be wrapped'
        $result.Tenants.Count | Should -BeExactly 1
        $result.Tenants[0].TenantName | Should -BeExactly 'Tenant One'
        $result.EndOfJson | Should -BeExactly 'EndOfJson'
    }

    It 'Should merge two tenant results into Tenants array' {
        $result = Merge-MtMaesterResult -MaesterResults @($tenant1, $tenant2)

        $result.Tenants | Should -Not -BeNullOrEmpty
        $result.Tenants.Count | Should -BeExactly 2
        $result.Tenants[0].TenantName | Should -BeExactly 'Tenant One'
        $result.Tenants[1].TenantName | Should -BeExactly 'Tenant Two'
    }

    It 'Should preserve shared metadata from the first result' {
        $result = Merge-MtMaesterResult -MaesterResults @($tenant1, $tenant2)

        $result.CurrentVersion | Should -BeExactly '2.0.0'
        $result.LatestVersion | Should -BeExactly '2.0.0'
    }

    It 'Should preserve all test data per tenant' {
        $result = Merge-MtMaesterResult -MaesterResults @($tenant1, $tenant2)

        $result.Tenants[0].Tests.Count | Should -BeExactly 2
        $result.Tenants[1].Tests.Count | Should -BeExactly 2
        $result.Tenants[0].TotalCount | Should -BeExactly 10
        $result.Tenants[1].TotalCount | Should -BeExactly 5
    }

    It 'Should throw when a result is missing the Tests property' {
        $invalid = [PSCustomObject]@{ TenantId = 'bad'; TenantName = 'Bad Tenant' }

        { Merge-MtMaesterResult -MaesterResults @($invalid) } | Should -Throw '*Tests*'
    }

    It 'Should include EndOfJson marker' {
        $result = Merge-MtMaesterResult -MaesterResults @($tenant1, $tenant2)

        $result.EndOfJson | Should -BeExactly 'EndOfJson'
    }

    It 'Should merge three or more tenant results' {
        $tenant3 = [PSCustomObject]@{
            TenantId       = 'tenant-3-id'
            TenantName     = 'Tenant Three'
            Result         = 'Passed'
            TotalCount     = 7
            PassedCount    = 7
            FailedCount    = 0
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Id = 'MT.1001'; Result = 'Passed'; Block = 'Maester' }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 7; TotalCount = 7 }
            )
            EndOfJson      = 'EndOfJson'
        }

        $result = Merge-MtMaesterResult -MaesterResults @($tenant1, $tenant2, $tenant3)

        $result.Tenants.Count | Should -BeExactly 3
        $result.Tenants[2].TenantName | Should -BeExactly 'Tenant Three'
        $result.Tenants[2].TotalCount | Should -BeExactly 7
    }

    It 'Should handle a result with empty TenantName' {
        $noName = [PSCustomObject]@{
            TenantId       = 'no-name-id'
            TenantName     = ''
            Result         = 'Passed'
            TotalCount     = 1
            PassedCount    = 1
            FailedCount    = 0
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Id = 'MT.1001'; Result = 'Passed'; Block = 'Maester' }
            )
            Blocks         = @()
            EndOfJson      = 'EndOfJson'
        }

        $result = Merge-MtMaesterResult -MaesterResults @($noName)

        $result.Tenants.Count | Should -BeExactly 1
        $result.Tenants[0].TenantName | Should -BeExactly ''
    }

    Context 'FromPath parameter set' {
        It 'Should merge results from file paths' {
            $result = Merge-MtMaesterResult -Path $file1, $file2

            $result | Should -Not -BeNullOrEmpty
            $result.Tenants | Should -Not -BeNullOrEmpty
            $result.Tenants.Count | Should -BeExactly 2
            $result.Tenants[0].TenantId | Should -BeExactly 'tenant-1-id'
            $result.Tenants[1].TenantId | Should -BeExactly 'tenant-2-id'
            $result.EndOfJson | Should -BeExactly 'EndOfJson'
        }

        It 'Should merge results from a directory' {
            $result = Merge-MtMaesterResult -Path $testDir

            $result | Should -Not -BeNullOrEmpty
            $result.Tenants.Count | Should -BeExactly 2
        }

        It 'Should merge results from a glob pattern' {
            $globPattern = Join-Path $testDir 'TestResults-*.json'
            $result = Merge-MtMaesterResult -Path $globPattern

            $result | Should -Not -BeNullOrEmpty
            $result.Tenants.Count | Should -BeExactly 2
        }

        It 'Should throw when path contains no valid results' {
            $emptyDir = Join-Path $testDir 'empty'
            New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null

            { Merge-MtMaesterResult -Path $emptyDir } | Should -Throw
        }

        It 'Should preserve test data when loading from files' {
            $result = Merge-MtMaesterResult -Path $file1, $file2

            $result.Tenants[0].Tests.Count | Should -BeExactly 2
            $result.Tenants[0].TotalCount | Should -BeExactly 10
            $result.Tenants[1].TotalCount | Should -BeExactly 5
        }
    }

    Context 'Pipeline input' {
        It 'Should accept pipeline input from Import-MtMaesterResult' {
            $result = Import-MtMaesterResult -Path $file1, $file2 | Merge-MtMaesterResult

            $result | Should -Not -BeNullOrEmpty
            $result.Tenants.Count | Should -BeExactly 2
            $result.Tenants[0].TenantName | Should -BeExactly 'Tenant One'
            $result.Tenants[1].TenantName | Should -BeExactly 'Tenant Two'
        }

        It 'Should accept pipeline input from in-memory objects' {
            $result = @($tenant1, $tenant2) | Merge-MtMaesterResult

            $result | Should -Not -BeNullOrEmpty
            $result.Tenants.Count | Should -BeExactly 2
        }

        It 'Should include all runs even when same TenantId appears multiple times' {
            # Two runs from the same tenant — both should be included
            $result = @($tenant1, $tenant1) | Merge-MtMaesterResult

            $result.Tenants.Count | Should -BeExactly 2
            $result.Tenants[0].TenantId | Should -BeExactly 'tenant-1-id'
            $result.Tenants[1].TenantId | Should -BeExactly 'tenant-1-id'
        }
    }
}

Describe 'Merge-MtMaesterResult -SameRun' {
    BeforeAll {
        function New-Partial {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([object[]] $Rows, [string] $RunId = 'run-1', [string] $Catalog = '3.0.0', [string] $Duration = '00:00:10.000')
            [PSCustomObject][ordered]@{
                Result         = if ($Rows | Where-Object Result -EQ 'Failed') { 'Failed' } else { 'Passed' }
                TotalCount     = $Rows.Count
                ExecutedAt     = '2026-10-01T10:00:00'
                TotalDuration  = $Duration
                TenantId       = 'tenant-1-id'
                CurrentVersion = $Catalog
                CatalogVersion = $Catalog
                RunMetadata    = [PSCustomObject]@{ RunId = $RunId }
                Selection      = [PSCustomObject]@{ BuiltIn = 'All'; UnknownIds = @(); Superseded = @(); IncludeTag = @(); ExcludeTag = @('Preview'); DryRun = $false }
                Tests          = $Rows
                Blocks         = @()
                EndOfJson      = 'EndOfJson'
            }
        }
        function New-Row { [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')] param($Id, $Result, $Block = 'Maester') [PSCustomObject]@{ Index = 0; Id = $Id; Name = "${Id}: test"; Result = $Result; Block = $Block } }
    }

    It 'Keeps the row that ran over the NotRun row of another partition' {
        $a = New-Partial -Rows @((New-Row -Id 'MT.1001' -Result 'Passed'), (New-Row -Id 'MT.1002' -Result 'NotRun'), (New-Row -Id 'MT.1003' -Result 'NotRun'))
        $b = New-Partial -Rows @((New-Row -Id 'MT.1001' -Result 'NotRun'), (New-Row -Id 'MT.1002' -Result 'Failed' -Block 'Exchange'), (New-Row -Id 'MT.1003' -Result 'NotRun')) -Duration '00:00:30.000'
        $m = Merge-MtMaesterResult -MaesterResults $a, $b -SameRun
        $m.PSObject.Properties.Name | Should -Not -Contain 'Tenants'
        $m.Tests | Should -HaveCount 3
        ($m.Tests | Where-Object Id -EQ 'MT.1001').Result | Should -Be 'Passed'
        ($m.Tests | Where-Object Id -EQ 'MT.1002').Result | Should -Be 'Failed'
        ($m.Tests | Where-Object Id -EQ 'MT.1003').Result | Should -Be 'NotRun'
        $m.PassedCount | Should -Be 1
        $m.FailedCount | Should -Be 1
        $m.NotRunCount | Should -Be 1
        $m.TotalCount | Should -Be 3
        $m.Result | Should -Be 'Failed'
        $m.TotalDuration | Should -Be '00:00:30.000'
        $m.Partitions | Should -HaveCount 2
        ($m.Blocks | Where-Object Name -EQ 'Exchange').FailedCount | Should -Be 1
        ($m.PSObject.Properties.Name)[-1] | Should -Be 'EndOfJson'
        $m.Selection.ExcludeTag | Should -Be @('Preview')
        $m.Selection.DryRun | Should -BeFalse
    }

    It 'Refuses partitions of different runs or catalog versions' {
        $a = New-Partial -Rows @(New-Row -Id 'MT.1001' -Result 'Passed')
        { Merge-MtMaesterResult -MaesterResults $a, (New-Partial -Rows @(New-Row -Id 'MT.1001' -Result 'Passed') -RunId 'run-2') -SameRun } | Should -Throw '*RunId*'
        { Merge-MtMaesterResult -MaesterResults $a, (New-Partial -Rows @(New-Row -Id 'MT.1001' -Result 'Passed') -Catalog '3.1.0') -SameRun } | Should -Throw '*catalog*'
    }
}
