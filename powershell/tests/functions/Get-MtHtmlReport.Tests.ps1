Describe 'Get-MtHtmlReport' {
    BeforeAll {
        # The function resolves the template relative to its own location (powershell/public/core/)
        # From the test directory (powershell/tests/functions/) the template is at ../../assets/
        $templatePath = Join-Path -Path $PSScriptRoot -ChildPath '../../assets/ReportTemplate.html'
        $templateAvailable = Test-Path $templatePath

        $singleTenant = [PSCustomObject]@{
            TenantId       = 'single-tenant-id'
            TenantName     = 'Single Tenant'
            Result         = 'Passed'
            TotalCount     = 5
            PassedCount    = 4
            FailedCount    = 1
            ErrorCount     = 0
            SkippedCount   = 0
            InvestigateCount = 0
            NotRunCount    = 0
            ExecutedAt     = '2026-03-30T10:00:00'
            TotalDuration  = '00:01:00'
            UserDuration   = '00:00:50'
            DiscoveryDuration = '00:00:08'
            FrameworkDuration = '00:00:01'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Account        = 'test@contoso.com'
            SystemInfo     = [PSCustomObject]@{ MachineName = 'TEST-01' }
            PowerShellInfo = [PSCustomObject]@{ Version = '7.4.1' }
            LoadedModules  = @()
            InvokeCommand  = 'Invoke-Maester'
            MgContext      = [PSCustomObject]@{ TenantId = 'single-tenant-id' }
            MaesterConfig  = [PSCustomObject]@{
                GlobalSettings = [PSCustomObject]@{
                    EmergencyAccessAccounts = @(
                        [PSCustomObject]@{
                            Type              = 'User'
                            UserPrincipalName = 'BreakGlass1@contoso.com'
                        }
                    )
                }
                TestSettings   = @()
            }
            Tests          = @(
                [PSCustomObject]@{
                    Index = 1; Id = 'MT.1001'; Title = 'Test One'
                    Name = 'MT.1001: Test One'; Result = 'Passed'
                    Severity = 'High'; Tag = @('MT.1001'); Block = 'Maester'
                    Duration = '00:00:01'; ErrorRecord = @()
                    ResultDetail = [PSCustomObject]@{ TestDescription = 'Desc'; TestResult = 'OK' }
                }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 4; FailedCount = 1; TotalCount = 5 }
            )
            EndOfJson      = 'EndOfJson'
        }

        $tenant1 = [PSCustomObject]@{
            TenantId       = 'tenant-1-id'
            TenantName     = 'Tenant One'
            Result         = 'Passed'
            TotalCount     = 3
            PassedCount    = 3
            FailedCount    = 0
            ErrorCount     = 0
            SkippedCount   = 0
            InvestigateCount = 0
            NotRunCount    = 0
            ExecutedAt     = '2026-03-30T10:00:00'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Index = 1; Id = 'MT.1001'; Result = 'Passed'; Block = 'Maester' }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 3; TotalCount = 3 }
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
            ErrorCount     = 0
            SkippedCount   = 0
            InvestigateCount = 0
            NotRunCount    = 0
            ExecutedAt     = '2026-03-30T11:00:00'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Index = 1; Id = 'MT.1001'; Result = 'Failed'; Block = 'Maester' }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 3; FailedCount = 2; TotalCount = 5 }
            )
            EndOfJson      = 'EndOfJson'
        }
    }

    Context 'Single-tenant report' {
        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Should generate valid HTML' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            $html | Should -Not -BeNullOrEmpty
            $html | Should -BeLike '*<!DOCTYPE html>*'
            $html | Should -BeLike '*</html>*'
        }

        It 'Should contain the tenant name in the output' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            $html | Should -BeLike '*Single Tenant*'
        }

        It 'Should contain the test data' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            $html | Should -BeLike '*MT.1001*'
        }

        It 'Should contain emergency access account config data' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            $html | Should -BeLike '*BreakGlass1@contoso.com*'
        }

        It 'Should not contain sample data from the template' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            $html | Should -Not -BeLike '*Pora Inc*'
        }
    }

    Context 'Multi-tenant report' {
        BeforeAll {
            $merged = Merge-MtMaesterResult -MaesterResults @($tenant1, $tenant2)
        }

        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Should generate valid HTML' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            $html | Should -Not -BeNullOrEmpty
            $html | Should -BeLike '*<!DOCTYPE html>*'
            $html | Should -BeLike '*</html>*'
        }

        It 'Should contain both tenant names' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            $html | Should -BeLike '*Tenant One*'
            $html | Should -BeLike '*Tenant Two*'
        }

        It 'Should not contain sample data from the template' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            $html | Should -Not -BeLike '*Pora Inc*'
        }

        It 'Should contain the Tenants key in the output' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            $html | Should -BeLike '*Tenants*'
        }

        It 'Should produce valid single-line JSON (no newlines in data region)' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            # Find the data region — it should be on a single line (compressed JSON)
            $tenantIdx = $html.IndexOf('"Tenant One"')
            if ($tenantIdx -gt 0) {
                # Get a chunk around the data
                $start = [Math]::Max(0, $tenantIdx - 50)
                $region = $html.Substring($start, [Math]::Min(200, $html.Length - $start))
                $region | Should -Not -BeLike "*`n*" -Because 'JSON should be compressed to a single line'
            }
        }
    }
}
