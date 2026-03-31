Describe 'Merge-MtMaesterResult' {
    BeforeAll {
        $tenant1 = [PSCustomObject]@{
            TenantId       = 'tenant-1-id'
            TenantName     = 'Tenant One'
            Result         = 'Passed'
            TotalCount     = 10
            PassedCount    = 8
            FailedCount    = 2
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
}
