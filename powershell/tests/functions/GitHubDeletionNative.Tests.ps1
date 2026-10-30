BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'GitHub deletion verdicts through the native engine and HTTP fixtures' {
    BeforeEach {
        $script:apiBase = 'https://api.github.com'
        $script:owners = @(@{ id = 1 }, @{ id = 2 })
        $script:responseHeaders = @{}
        $script:status = 200
        $script:config = @{
            GlobalSettings = @{
                GitHubDeletionPolicy = @{
                    ApiBaseUri = $script:apiBase
                    OrganizationId = '100'
                    ApprovedOwnerIds = @('1', '2', '3', '4', '9876543210123')
                }
            }
        }
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer synthetic-never-network'; 'X-GitHub-Api-Version' = '2022-11-28' }
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = $null
            $__MtSession.MaesterConfig = $null
        }
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Method -ne 'GET' -or $Headers['X-GitHub-Api-Version'] -ne '2026-03-10' -or $Uri -notlike "$script:apiBase/*") { throw 'Unexpected native fixture request.' }
            $path = ([uri]$Uri).PathAndQuery
            if ($path -eq '/orgs/fixture-org') {
                return [pscustomobject]@{ Content = '{"id":100,"login":"fixture-org","members_can_delete_repositories":false,"members_can_delete_issues":false}'; Headers = @{} }
            }
            if ($path -ne '/orgs/fixture-org/members?role=admin&per_page=100') { throw 'Unrecognized fixture endpoint; network is forbidden.' }
            if ($script:status -ne 200) {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$script:status)
                foreach ($key in $script:responseHeaders.Keys) { $null = $response.Headers.TryAddWithoutValidation($key, [string]$script:responseHeaders[$key]) }
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic owner collection failure', $response)
            }
            return [pscustomobject]@{ Content = ConvertTo-Json -InputObject $script:owners -Compress; Headers = $script:responseHeaders }
        }
    }
    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = $null
            $__MtSession.MaesterConfig = $null
        }
    }

    It 'Returns Passed for both existing checks with a longer approved list and two actual owners' {
        $rows = @(Invoke-MtTest -Id 'CIS.GH.1.2.3', 'CIS.GH.1.2.4' -Config $script:config)
        $rows.Count | Should -Be 2
        @($rows | Where-Object Result -NE 'Passed').Count | Should -Be 0
        ($rows.ResultDetail.TestResult -join '') | Should -Not -Match '9876543210123|synthetic-never-network'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -Exactly
    }

    It 'Returns Failed for four live approved owners despite a five-entry approval list' {
        $script:owners += @{ id = 3 }, @{ id = 4 }
        $row = Invoke-MtTest -Id 'CIS.GH.1.2.3' -Config $script:config
        $row.Result | Should -Be 'Failed'
        $row.ResultDetail.TestResult | Should -Match '\| 4 \| 3 \| 0 \|'
        $row.ResultDetail.TestResult | Should -Not -Match '9876543210123'
    }

    It 'Keeps partial SSO owner visibility indeterminate' {
        $script:responseHeaders = @{ 'X-GitHub-SSO' = 'partial-results; organizations=100' }
        $row = Invoke-MtTest -Id 'CIS.GH.1.2.4' -Config $script:config
        $row.Result | Should -Be 'Skipped'
        $row.ReasonDetail | Should -Match 'Indeterminate'
    }

    It 'Rejects an approval policy for a different organization through the engine' {
        $script:config.GlobalSettings.GitHubDeletionPolicy.OrganizationId = '101'
        $row = Invoke-MtTest -Id 'CIS.GH.1.2.3' -Config $script:config
        $row.Result | Should -Be 'Error'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -Exactly
    }

    It 'Routes GHE.com evidence and validates the matching host-bound policy' {
        $script:apiBase = 'https://api.fixture.ghe.com'
        $script:config.GlobalSettings.GitHubDeletionPolicy.ApiBaseUri = $script:apiBase
        InModuleScope Maester { $__MtSession.GitHubConnection.ApiBaseUri = 'https://api.fixture.ghe.com' }
        (Invoke-MtTest -Id 'CIS.GH.1.2.3' -Config $script:config).Result | Should -Be 'Passed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -Exactly -ParameterFilter { $Uri -like 'https://api.fixture.ghe.com/*' }
    }

    It 'Stops requests across the two native checks after a shared secondary limit' {
        $script:status = 429
        $script:responseHeaders = @{ 'retry-after' = '120' }
        $rows = @(Invoke-MtTest -Id 'CIS.GH.1.2.3', 'CIS.GH.1.2.4' -Config $script:config)
        $rows.Count | Should -Be 2
        @($rows | Where-Object Result -NE 'Error').Count | Should -Be 0
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -Exactly
    }

    It 'Retains required owner-access denials as Error rather than zero owners' {
        $script:status = 403
        (Invoke-MtTest -Id 'CIS.GH.1.2.4' -Config $script:config).Result | Should -Be 'Error'
    }

    It 'Exports an executed Passed result without unused approvals in JSON, HTML or verbose output' {
        $jsonPath = Join-Path $TestDrive 'executed.json'
        $htmlPath = Join-Path $TestDrive 'executed.html'
        $captured = @(Invoke-Maester -Config $script:config -TestId CIS.GH.1.2.3 -PassThru -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputJsonFile $jsonPath -OutputHtmlFile $htmlPath -Verbose 4>&1)
        $result = $captured | Where-Object { $_.PSObject.Properties['Tests'] } | Select-Object -Last 1
        ($result.Tests | Where-Object Id -EQ 'CIS.GH.1.2.3').Result | Should -Be 'Passed'
        ($captured | Out-String) | Should -Not -Match '9876543210123|synthetic-never-network'
        foreach ($path in $jsonPath, $htmlPath) {
            $content = Get-Content $path -Raw
            $content | Should -Not -Match '9876543210123|synthetic-never-network'
            $content | Should -Match 'GitHubDeletionPolicy'
            $content | Should -Match 'redacted'
        }
    }
}
