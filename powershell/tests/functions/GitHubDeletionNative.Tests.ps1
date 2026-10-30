[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Pester supplies this container parameter to BeforeAll for source and built-module validation.')]
[CmdletBinding()]
param([string] $ModulePath = "$PSScriptRoot/../../Maester.psd1")

BeforeAll {
    Import-Module $ModulePath -Force
}

Describe 'GitHub deletion verdicts through the native engine and HTTP fixtures' {
    BeforeEach {
        $script:apiBase = 'https://api.github.com'
        $script:owners = @(@{ id = 1; login = 'fixture-owner-one' }, @{ id = 2; login = 'fixture-owner-two' })
        $script:responseHeaders = @{}
        $script:status = 200
        $script:partialError = $false
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
            if ($script:partialError -and $path -like '*page=2*') { throw 'fixture-owner-one: 90123456789 parsing failure' }
            if ($path -ne '/orgs/fixture-org/members?role=admin&per_page=100') { throw 'Unrecognized fixture endpoint; network is forbidden.' }
            if ($script:status -ne 200) {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$script:status)
                foreach ($key in $script:responseHeaders.Keys) { $null = $response.Headers.TryAddWithoutValidation($key, [string]$script:responseHeaders[$key]) }
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic owner collection failure', $response)
            }
            if ($script:partialError) { $script:responseHeaders.Link = '<https://api.github.com/orgs/fixture-org/members?role=admin&page=2>; rel="next"' }
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

    It 'Exports both observed owner rosters through Invoke-Maester without approval configuration' {
        $jsonPath = Join-Path $TestDrive 'unconfigured.json'
        $htmlPath = Join-Path $TestDrive 'unconfigured.html'
        $result = Invoke-Maester -Config @{ GlobalSettings = @{} } -TestId CIS.GH.1.2.3, CIS.GH.1.2.4 -PassThru -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputJsonFile $jsonPath -OutputHtmlFile $htmlPath
        $rows = @($result.Tests | Where-Object Id -In 'CIS.GH.1.2.3', 'CIS.GH.1.2.4')
        $rows.Count | Should -Be 2
        @($rows | Where-Object Result -NE 'Investigate').Count | Should -Be 0
        foreach ($row in $rows) {
            $row.ResultDetail.TestResult | Should -Match ([regex]::Escape('| fixture-owner-one | 1 | Not configured |'))
            $row.ResultDetail.TestResult | Should -Match ([regex]::Escape('| fixture-owner-two | 2 | Not configured |'))
        }
        $export = Get-Content $jsonPath -Raw | ConvertFrom-Json
        $exportRows = @($export.Tests | Where-Object Id -In 'CIS.GH.1.2.3', 'CIS.GH.1.2.4')
        $exportRows.Count | Should -Be 2
        foreach ($row in $exportRows) {
            $row.Result | Should -Be 'Investigate'
            $row.ResultDetail.TestResult | Should -Match 'fixture-owner-one|fixture-owner-two'
        }
        foreach ($path in $jsonPath, $htmlPath) {
            $content = Get-Content $path -Raw
            $content.Contains('fixture-owner-one') | Should -BeTrue
            $content.Contains('fixture-owner-two') | Should -BeTrue
            $content | Should -Not -Match '9876543210123|synthetic-never-network'
        }
    }

    It 'Protects displayed identities in <Mode> exports with an empty generic map' -ForEach @(
        @{ Mode = 'None' }, @{ Mode = 'HtmlOnly' }, @{ Mode = 'AllOutputs' }
    ) {
        Mock Get-MtUserIdentityReplacementMap -ModuleName Maester { @{} }
        $script:excelInput = $null
        Mock Convert-MtResultsToFlatObject -ModuleName Maester -ParameterFilter { $ExcelFilePath } { $script:excelInput = $InputObject }
        $folder = Join-Path $TestDrive $Mode
        $xmlPath = Join-Path $TestDrive "$Mode.xml"
        $script:config.Output = @{ TestResult = @{ Path = $xmlPath; Format = 'JUnitXml' } }
        $result = Invoke-Maester -Config $script:config -TestId CIS.GH.1.2.3, CIS.GH.1.2.4 -PassThru -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputFolder $folder -OutputFolderFileName result -ExportCsv -ExportExcel -RedactUserIdentity $Mode -IncludeAffectedObjects
        $rows = @($result.Tests | Where-Object Id -In 'CIS.GH.1.2.3', 'CIS.GH.1.2.4')
        @($rows | Where-Object Result -NE 'Passed').Count | Should -Be 0
        ($rows.ResultDetail.TestResult -join '') | Should -Match 'fixture-owner-one'
        $result.AffectedObjects.Type | Should -Contain 'GitHubOrganization'
        foreach ($extension in 'json', 'html', 'md', 'csv') {
            $content = Get-Content (Join-Path $folder "result.$extension") -Raw
            if ($Mode -eq 'AllOutputs' -or ($Mode -eq 'HtmlOnly' -and $extension -eq 'html')) {
                $content | Should -Not -Match 'fixture-owner-one|fixture-owner-two|TestResultRedacted'
                $content | Should -Match 'object-[a-f0-9]{16}'
            } else {
                $content | Should -Match 'fixture-owner-one'
            }
        }
        Should -Invoke Convert-MtResultsToFlatObject -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $ExcelFilePath }
        $excelJson = $script:excelInput | ConvertTo-Json -Depth 15
        if ($Mode -eq 'AllOutputs') { $excelJson | Should -Not -Match 'fixture-owner-one|fixture-owner-two|TestResultRedacted' }
        else { $excelJson | Should -Match 'fixture-owner-one' }
        ([xml](Get-Content $xmlPath -Raw)).testsuites | Should -Not -BeNullOrEmpty
        $xml = Get-Content $xmlPath -Raw
        $xml | Should -Not -Match 'fixture-owner-one|fixture-owner-two'
        $export = Get-Content (Join-Path $folder 'result.json') -Raw | ConvertFrom-Json
        $exportRows = @($export.Tests | Where-Object Id -In 'CIS.GH.1.2.3', 'CIS.GH.1.2.4')
        @($exportRows | Where-Object Result -NE 'Passed').Count | Should -Be 0
        foreach ($row in $exportRows) { $row.ResultDetail.TestResult | Should -Match '\| 2 \| 3 \| 0 \| Complete' }
        $before = $export | ConvertTo-Json -Depth 15
        $standalone = Get-MtHtmlReport -MaesterResults $export -RedactUserIdentity HtmlOnly -UserIdentityReplacementMap @{}
        $standalone | Should -Not -Match 'fixture-owner-one|fixture-owner-two|TestResultRedacted'
        ($export | ConvertTo-Json -Depth 15) | Should -BeExactly $before
    }

    It 'Retains partial owner evidence on Error without leaking identities through error metadata' {
        $script:partialError = $true
        $script:owners = @(@{ id = 90123456789; login = 'fixture-owner-one' })
        Mock Get-MtUserIdentityReplacementMap -ModuleName Maester { @{} }
        $folder = Join-Path $TestDrive 'error'
        $script:config.Output = @{ TestResult = @{ Path = (Join-Path $TestDrive 'error.xml'); Format = 'JUnitXml' } }
        $result = Invoke-Maester -Config $script:config -TestId CIS.GH.1.2.3 -PassThru -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputFolder $folder -OutputFolderFileName result -ExportCsv -RedactUserIdentity AllOutputs
        $row = $result.Tests | Where-Object Id -EQ 'CIS.GH.1.2.3'
        $row.Result | Should -Be 'Error'
        $row.ResultDetail.TestResult | Should -Match 'fixture-owner-one'
        foreach ($extension in 'json', 'html', 'md', 'csv') {
            $content = Get-Content (Join-Path $folder "result.$extension") -Raw
            $content | Should -Not -Match 'fixture-owner-one|90123456789|GitHubPartialResponse|TestResultRedacted'
            $content | Should -Match 'object-[a-f0-9]{16}'
        }
        (Get-Content (Join-Path $TestDrive 'error.xml') -Raw) | Should -Not -Match 'fixture-owner-one|90123456789'
    }

    It 'Applies the generic map once across AllOutputs JSON and HTML' {
        Mock Get-MtUserIdentityReplacementMap -ModuleName Maester { @{ 'fixture-org' = 'object-first'; 'object-first' = 'object-second' } }
        $folder = Join-Path $TestDrive 'once'
        $null = Invoke-Maester -Config $script:config -TestId CIS.GH.1.2.3 -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputFolder $folder -OutputFolderFileName result -RedactUserIdentity AllOutputs -IncludeAffectedObjects
        foreach ($extension in 'json', 'html') {
            $content = Get-Content (Join-Path $folder "result.$extension") -Raw
            $content | Should -Match 'object-first'
            $content | Should -Not -Match 'object-second'
        }
    }

    It 'Redacts unapproved administrator IDs while preserving numeric counts through native exports' {
        Mock Get-MtUserIdentityReplacementMap -ModuleName Maester { @{} }
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Method -ne 'GET' -or $Headers['X-GitHub-Api-Version'] -ne '2026-03-10') { throw 'Unexpected administrator fixture request.' }
            $data = switch (([uri]$Uri).PathAndQuery) {
                '/orgs/fixture-org' { @{ id = 100; members_can_delete_issues = $true } }
                '/orgs/fixture-org/repos?type=all&per_page=100' { ,@(@{ id = 200; name = 'fixture-repo'; full_name = 'fixture-org/fixture-repo'; owner = @{ login = 'fixture-org' } }) }
                '/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100' { ,@(1..3 | ForEach-Object { @{ id = $_; permissions = @{ admin = $true } } }) }
                default { throw 'Unexpected fixture endpoint; network is forbidden.' }
            }
            [pscustomobject]@{ Content = ConvertTo-Json -InputObject $data -Depth 8 -Compress; Headers = @{} }
        }
        $script:config.GlobalSettings.GitHubDeletionPolicy.CompleteRepositoryInventory = $true
        $script:config.GlobalSettings.GitHubDeletionPolicy.Repositories = @(@{ Id = '200'; ApprovedAdministratorIds = @('1', '2') })
        $folder = Join-Path $TestDrive 'administrators'
        $result = Invoke-Maester -Config $script:config -TestId CIS.GH.1.2.4 -PassThru -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputFolder $folder -OutputFolderFileName result -ExportCsv -RedactUserIdentity AllOutputs
        $row = $result.Tests | Where-Object Id -EQ 'CIS.GH.1.2.4'
        $row.Result | Should -Be 'Failed'
        $row.ResultDetail.TestResult | Should -Match '\| fixture-repo \| 3 \| 1 \| 3 \|'
        foreach ($extension in 'json', 'html', 'md', 'csv') {
            $content = Get-Content (Join-Path $folder "result.$extension") -Raw
            $content | Should -Not -Match '\| fixture-repo \| 3 \| 1 \| 3 \||TestResultRedacted'
            $content | Should -Match '\| fixture-repo \| 3 \| 1 \| object-[a-f0-9]{16} \|'
        }
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
            $content.Contains('fixture-owner-one') | Should -BeTrue
            $content.Contains('fixture-owner-two') | Should -BeTrue
        }
    }
}
