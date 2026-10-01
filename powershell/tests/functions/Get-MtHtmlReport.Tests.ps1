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

        It 'Should not embed a raw script injection payload' {
            $payload = "</script><script>alert('XSS')</script>"
            $maliciousResults = [PSCustomObject]@{
                TenantName = $payload
                EndOfJson  = 'EndOfJson'
            }

            $html = Get-MtHtmlReport -MaesterResults $maliciousResults

            $html | Should -Not -BeLike "*$payload*"
        }
    }

    Context 'Embedded JSON safety' {
        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Preserves hostile values without introducing script markup (multi-tenant: <_>)' -ForEach @($false, $true) {
            $payload = "</script><script>alert('XSS')</script><!--<script> & > " + '\u003c \\ path\file' + [char]0x2028
            $results = [ordered]@{ TenantName = $payload }
            if ($_) {
                $results.Tenants = @(@{ Tests = @(@{ ResultDetail = @{ TestResult = $payload } }) })
            }
            $results.EndOfJson = 'EndOfJson'

            $html = Get-MtHtmlReport -MaesterResults ([PSCustomObject]$results)
            $json = [regex]::Match($html, '\{"TenantName":.*?"EndOfJson":"EndOfJson"\}').Value
            $json | Should -Not -BeNullOrEmpty
            $json | Should -Not -Match '[<>&]'
            $decoded = $json | ConvertFrom-Json
            $decoded.TenantName | Should -BeExactly $payload
            if ($_) {
                $decoded.Tenants[0].Tests[0].ResultDetail.TestResult | Should -BeExactly $payload
            }
            $template = Get-Content $templatePath -Raw
            ([regex]::Matches($html, '</script', 'IgnoreCase')).Count |
                Should -Be ([regex]::Matches($template, '</script', 'IgnoreCase')).Count
        }
    }

    Context 'ErrorRecord is left out of the report' {
        BeforeAll {
            # Reads the embedded results back out of the HTML, the reverse of how Get-MtHtmlReport inserts them.
            function Get-EmbeddedResult([string] $Html) {
                # Each tenant has its own EndOfJson, so the results end at the last one.
                $end = $Html.LastIndexOf('"EndOfJson":"EndOfJson"}') + '"EndOfJson":"EndOfJson"}'.Length
                $start = [regex]::Matches($Html.Substring(0, $end), '(?:var|const|let)\s+\w+\s*=') | Select-Object -Last 1
                $Html.Substring($start.Index + $start.Length, $end - $start.Index - $start.Length) | ConvertFrom-Json
            }

            function New-ResultWithErrorRecord([string] $TenantName) {
                [PSCustomObject]@{
                    TenantName = $TenantName
                    Tests      = @(
                        [PSCustomObject]@{
                            Id           = 'MT.1001'
                            Result       = 'Failed'
                            ScriptBlock  = 'Test-MtExample | Should -Be $true'
                            ErrorRecord  = @([PSCustomObject]@{ ScriptStackTrace = 'at <ScriptBlock>, /Users/someone/maester-tests/Example.Tests.ps1: line 1' })
                            ResultDetail = [PSCustomObject]@{ TestResult = 'Example result' }
                        }
                    )
                    EndOfJson  = 'EndOfJson'
                }
            }
        }

        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Omits ErrorRecord and keeps the other test fields (single-tenant)' {
            $results = New-ResultWithErrorRecord -TenantName 'Single Tenant'

            $html = Get-MtHtmlReport -MaesterResults $results
            $embedded = Get-EmbeddedResult $html

            $html | Should -Not -BeLike '*/Users/someone/*'
            # A single test must still serialize as an array for the report.
            , $embedded.Tests | Should -BeOfType [array]
            $embedded.Tests[0].PSObject.Properties.Name | Should -Not -Contain 'ErrorRecord'
            $embedded.Tests[0].ScriptBlock | Should -BeExactly 'Test-MtExample | Should -Be $true'
            $embedded.Tests[0].ResultDetail.TestResult | Should -BeExactly 'Example result'
        }

        It 'Omits ErrorRecord from every tenant (multi-tenant)' {
            $merged = Merge-MtMaesterResult -MaesterResults @(
                (New-ResultWithErrorRecord -TenantName 'Tenant One'),
                (New-ResultWithErrorRecord -TenantName 'Tenant Two')
            )

            $html = Get-MtHtmlReport -MaesterResults $merged
            $embedded = Get-EmbeddedResult $html

            $html | Should -Not -BeLike '*/Users/someone/*'
            $embedded.Tenants.TenantName | Should -Be @('Tenant One', 'Tenant Two')
            foreach ($tenant in $embedded.Tenants) {
                $tenant.Tests[0].PSObject.Properties.Name | Should -Not -Contain 'ErrorRecord'
                $tenant.Tests[0].ResultDetail.TestResult | Should -BeExactly 'Example result'
            }
        }

        It 'Leaves the MaesterResults passed in unchanged' {
            $results = New-ResultWithErrorRecord -TenantName 'Single Tenant'
            $merged = Merge-MtMaesterResult -MaesterResults @((New-ResultWithErrorRecord -TenantName 'Tenant One'))

            $null = Get-MtHtmlReport -MaesterResults $results
            $null = Get-MtHtmlReport -MaesterResults $merged

            $results.Tests[0].ErrorRecord | Should -Not -BeNullOrEmpty
            $merged.Tenants[0].Tests[0].ErrorRecord | Should -Not -BeNullOrEmpty
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
