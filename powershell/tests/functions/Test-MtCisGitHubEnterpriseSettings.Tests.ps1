BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'CIS GitHub enterprise-dependent native assessments' {
    BeforeEach {
        $script:verificationBody = '{"data":{"organization":{"id":"O_1","login":"fixture-org","isVerified":true}}}'
        $script:associationBody = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","organizations":{"nodes":[{"id":"O_1","login":"fixture-org"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        $script:notificationBody = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","ownerInfo":{"notificationDeliveryRestrictionEnabledSetting":"ENABLED"}}}}'
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{}
            $__MtSession.GitHubCache = @{}
            $__MtSession.MaesterConfig = $null
        }
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Method -ne 'POST' -or $Uri -notmatch '/graphql$') { throw 'Unexpected fixture request.' }
            $request = $Body | ConvertFrom-Json
            $content = switch ($request.operationName) {
                MaesterCisVerification { $script:verificationBody }
                MaesterCisAssociation { $script:associationBody }
                MaesterCisNotifications { $script:notificationBody }
                default { throw 'Unexpected GraphQL operation.' }
            }
            [pscustomobject]@{ Content = $content; Headers = @{} }
        }
    }
    AfterEach { InModuleScope Maester { $__MtSession.GitHubConnection = $null; $__MtSession.GitHubAuthHeader = $null; $__MtSession.GitHubCache = @{}; $__MtSession.MaesterConfig = $null } }

    It 'Assesses profile verification <Value> as <Expected> without ownerInfo' -ForEach @(
        @{ Value = 'true'; Expected = 'Passed' }, @{ Value = 'false'; Expected = 'Failed' }
    ) {
        $script:verificationBody = '{"data":{"organization":{"id":"O_1","login":"fixture-org","isVerified":' + $Value + '}}}'
        $row = Invoke-MtTest -Id CIS.GH.1.3.9 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }
        $row.Result | Should -Be $Expected
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0 -ParameterFilter { ($Body | ConvertFrom-Json).query -match 'ownerInfo' }
    }
    It 'Rejects unavailable/defensive profile shape <Body>' -ForEach @(
        @{ Body = '{"data":{"organization":null}}' }
        @{ Body = '{"data":{"organization":{"id":"O_1","login":"fixture-org","isVerified":null}}}' }
        @{ Body = '{"data":{"organization":{"id":"O_1","login":"fixture-org","isVerified":"true"}}}' }
        @{ Body = '{"data":{"organization":[{"id":"O_1","login":"fixture-org","isVerified":true}]}}' }
        @{ Body = '{"data":[{"organization":{"id":"O_1","login":"fixture-org","isVerified":true}}]}' }
    ) {
        $script:verificationBody = $Body
        (Invoke-MtTest -Id CIS.GH.1.3.9 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Skipped'
    }
    It 'Requires a positive identity association rather than a matching name alone' {
        $script:associationBody = $script:associationBody.Replace('O_1','O_2')
        (Invoke-MtTest -Id CIS.GH.1.3.9 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Skipped'
    }
    It 'Does not call a field unavailable to the verification control' {
        $script:associationBody = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","organizations":{"nodes":[{"id":"O_1","login":"fixture-org"}]}}}}'
        (Invoke-MtTest -Id CIS.GH.1.3.9 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Passed'
    }
    It 'Follows association cursors until a positive match is found' {
        $script:associationBody = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","organizations":{"nodes":[],"pageInfo":{"hasNextPage":true,"endCursor":"next"}}}}}'
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { ($Body | ConvertFrom-Json).operationName -eq 'MaesterCisAssociation' -and ($Body | ConvertFrom-Json).variables.after -eq 'next' } {
            [pscustomobject]@{ Content = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","organizations":{"nodes":[{"id":"O_1","login":"fixture-org"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'; Headers = @{} }
        }
        (Invoke-MtTest -Id CIS.GH.1.3.9 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Passed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2 -ParameterFilter { ($Body | ConvertFrom-Json).operationName -eq 'MaesterCisAssociation' }
    }
    It 'Treats an association cursor cycle as an execution error' {
        $script:associationBody = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","organizations":{"nodes":[],"pageInfo":{"hasNextPage":true,"endCursor":"repeat"}}}}}'
        (Invoke-MtTest -Id CIS.GH.1.3.9 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Error'
    }
    It 'Assesses independent enterprise notification <Value> as <Expected>' -ForEach @(
        @{ Value = 'ENABLED'; Expected = 'Passed' }, @{ Value = 'DISABLED'; Expected = 'Failed' }
    ) {
        $script:notificationBody = $script:notificationBody.Replace('ENABLED',$Value)
        $row = Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise'; GitHubCisRepositoryScope = $false } }
        $row.Result | Should -Be $Expected
        $row.ResultDetail.TestResult | Should -Match 'independently targeted enterprise-setting audit'
        $row.ResultDetail.TestResult | Should -Match 'fixture-enterprise'
        $row.ResultDetail.TestResult | Should -Not -Match 'fixture-org'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0 -ParameterFilter { ($Body | ConvertFrom-Json).query -match 'organizations|isVerified' }
    }
    It 'Does not substitute missing, nullable or malformed notification evidence <Body>' -ForEach @(
        @{ Body = '{"data":{"enterprise":null}}' }
        @{ Body = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","ownerInfo":null}}}' }
        @{ Body = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","ownerInfo":{"notificationDeliveryRestrictionEnabledSetting":null}}}}' }
        @{ Body = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","ownerInfo":{"notificationDeliveryRestrictionEnabledSetting":"enabled"}}}}' }
        @{ Body = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","ownerInfo":[{"notificationDeliveryRestrictionEnabledSetting":"ENABLED"}]}}}' }
        @{ Body = '{"data":{"enterprise":[{"id":"E_1","slug":"fixture-enterprise","ownerInfo":{"notificationDeliveryRestrictionEnabledSetting":"ENABLED"}}]}}' }
        @{ Body = '{"data":{"enterprise":{"id":"E_1","slug":"different","ownerInfo":{"notificationDeliveryRestrictionEnabledSetting":"ENABLED"}}}}' }
    ) {
        $script:notificationBody = $Body
        (Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Skipped'
    }
    It 'Retains unknown rather than inferring non-applicability when enterprise context is absent' {
        $row = Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{}
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Not -Be 'NotApplicable'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0
    }
    It 'Rejects a malformed configured enterprise target' {
        (Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{ GlobalSettings = @{ GitHubEnterprise = @('fixture-enterprise') } }).Result | Should -Be 'Error'
    }
    It 'Keeps field-access errors indeterminate and uncached' {
        $script:notificationBody = '{"data":{"enterprise":{"id":"E_1","slug":"fixture-enterprise","ownerInfo":null}},"errors":[{"type":"FORBIDDEN"}]}'
        (Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Skipped'
        InModuleScope Maester { $__MtSession.GitHubCache.Count } | Should -Be 0
    }
    It 'Uses changed enterprise targets on subsequent real configuration resolutions' {
        (Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Passed'
        $script:notificationBody = $script:notificationBody.Replace('fixture-enterprise','second-enterprise').Replace('ENABLED','DISABLED')
        (Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'second-enterprise' } }).Result | Should -Be 'Failed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
    It 'Does not render unrecognized enum data as raw Markdown' {
        $script:notificationBody = $script:notificationBody.Replace('ENABLED','<script>|`untrusted')
        $row = Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }
        $row.Result | Should -Be 'Skipped'
        $row.ResultDetail.TestResult | Should -Not -Match '<script>|`untrusted'
        $row.ResultDetail.TestResult | Should -Match 'unavailable'
    }
    It 'Keeps HTTP and malformed JSON failures as execution errors' {
        $script:notificationBody = '{bad'
        (Invoke-MtTest -Id CIS.GH.1.3.10 -Config @{ GlobalSettings = @{ GitHubEnterprise = 'fixture-enterprise' } }).Result | Should -Be 'Error'
    }
    It 'Does not query profile data when required enterprise applicability context is unconfigured' {
        (Invoke-MtTest -Id CIS.GH.1.3.9 -Config @{}).Result | Should -Be 'Skipped'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0
    }

}
