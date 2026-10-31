BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'CIS GitHub MFA through configuration, transport and native results' {
    BeforeEach {
        $script:mfaBody = '{"login":"fixture-org","two_factor_requirement_enabled":true}'
        $script:mfaHeaders = @{}
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ 'X-GitHub-Api-Version' = '2022-11-28' }
            $__MtSession.GitHubCache = @{}
            $__MtSession.MaesterConfig = $null
        }
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Uri -ne 'https://api.github.com/orgs/fixture-org' -or $Method -ne 'GET') { throw 'Unexpected fixture request.' }
            [pscustomobject]@{ Content = $script:mfaBody; Headers = $script:mfaHeaders }
        }
    }
    AfterEach { InModuleScope Maester { $__MtSession.GitHubConnection = $null; $__MtSession.GitHubAuthHeader = $null; $__MtSession.GitHubCache = @{}; $__MtSession.MaesterConfig = $null } }

    It '<Id> evaluates documented Boolean <Value> as <Expected>' -ForEach @(
        @{ Id = 'CIS.GH.1.3.4'; Value = 'true'; Expected = 'Passed' }
        @{ Id = 'CIS.GH.1.3.4'; Value = 'false'; Expected = 'Failed' }
        @{ Id = 'CIS.GH.1.3.5'; Value = 'true'; Expected = 'Passed' }
        @{ Id = 'CIS.GH.1.3.5'; Value = 'false'; Expected = 'Failed' }
    ) {
        $script:mfaBody = '{"two_factor_requirement_enabled":' + $Value + '}'
        $row = @(Invoke-MtTest -Id $Id -Config @{ GlobalSettings = @{ GitHubAccountModel = 'PersonalAccounts' } })
        $row.Count | Should -Be 1
        $row[0].Result | Should -Be $Expected
        $row[0].ResultDetail.TestResult | Should -Match 'fixture-org'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Headers['X-GitHub-Api-Version'] -eq '2026-03-10' }
    }
    It 'Keeps missing/nullable and defensive unusable <Body> indeterminate for <Id>' -ForEach @(
        foreach ($id in 'CIS.GH.1.3.4', 'CIS.GH.1.3.5') {
            foreach ($body in '{}','{"two_factor_requirement_enabled":null}','{"two_factor_requirement_enabled":"true"}','{"two_factor_requirement_enabled":1}','{"two_factor_requirement_enabled":[]}','[{"two_factor_requirement_enabled":true}]','null','true','') { @{ Id = $id; Body = $body } }
        }
    ) {
        $script:mfaBody = $Body
        $row = Invoke-MtTest -Id $Id -Config @{ GlobalSettings = @{ GitHubAccountModel = 'PersonalAccounts' } }
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'TestSkipped'
        $row.ResultDetail.TestResult | Should -Match 'Indeterminate'
    }
    It 'Does not turn a partial SSO body into a pass' {
        $script:mfaHeaders = @{ 'X-GitHub-SSO' = 'partial-results; organizations=1' }
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config @{ GlobalSettings = @{ GitHubAccountModel = 'PersonalAccounts' } }).Result | Should -Be 'Skipped'
    }
    It 'Requires relevant account context <Model> before collection' -ForEach @(
        @{ Model = 'Unknown' }, @{ Model = 'EnterpriseManagedUsers' }
    ) {
        $row = Invoke-MtTest -Id CIS.GH.1.3.4 -Config @{ GlobalSettings = @{ GitHubAccountModel = $Model } }
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Not -Be 'NotApplicable'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0
    }
    It 'Does not infer MFA from a GHE.com organization flag' {
        InModuleScope Maester { $__MtSession.GitHubConnection.ApiBaseUri = 'https://api.fixture.ghe.com' }
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config @{ GlobalSettings = @{ GitHubAccountModel = 'PersonalAccounts' } }).Result | Should -Be 'Skipped'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0
    }
    It 'Reports malformed configured account model <Model> as Error' -ForEach @(
        @{ Model = $true }, @{ Model = 'Other' }, @{ Model = @('PersonalAccounts') }, @{ Model = $null }
    ) {
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config @{ GlobalSettings = @{ GitHubAccountModel = $Model } }).Result | Should -Be 'Error'
    }
    It 'Rejects a configured organization mismatch without relabeling the connection' {
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config @{ GlobalSettings = @{ GitHubAccountModel = 'PersonalAccounts'; GitHubOrganization = 'other-org' } }).Result | Should -Be 'Error'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0
    }
    It 'Recomputes account applicability after a configuration change despite cached raw evidence' {
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config @{ GlobalSettings = @{ GitHubAccountModel = 'PersonalAccounts' } }).Result | Should -Be 'Passed'
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config @{ GlobalSettings = @{ GitHubAccountModel = 'EnterpriseManagedUsers' } }).Result | Should -Be 'Skipped'
        InModuleScope Maester { $__MtSession.MaesterConfig } | Should -BeNullOrEmpty
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
    }
    It 'Uses an actual JSON configuration file and ignores unrelated malformed scope fields' {
        $file = Join-Path $TestDrive 'mfa.json'
        '{"GlobalSettings":{"GitHubAccountModel":"PersonalAccounts","GitHubCisRepositoryScope":false}}' | Set-Content $file
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config $file).Result | Should -Be 'Passed'
    }
    It 'Reports request HTTP <Status> as Error, not disabled or not-applicable' -ForEach @(
        @{ Status = 401 }, @{ Status = 403 }, @{ Status = 404 }, @{ Status = 429 }, @{ Status = 500 }
    ) {
        Mock Invoke-WebRequest -ModuleName Maester { throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic HTTP failure', [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)) }
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config @{ GlobalSettings = @{ GitHubAccountModel = 'PersonalAccounts' } }).Result | Should -Be 'Error'
    }
    It 'Keeps invalid JSON as an execution error' {
        $script:mfaBody = '{bad'
        (Invoke-MtTest -Id CIS.GH.1.3.5 -Config @{ GlobalSettings = @{ GitHubAccountModel = 'PersonalAccounts' } }).Result | Should -Be 'Error'
    }
}
