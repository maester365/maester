BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    # Check functions that became native tests are not exported.
    Use-MtModuleFunction -Name Test-MtCisGitHubRepositoryCreationLimited, Test-MtCisGitHubRepositoryDeletionLimited, Test-MtCisGitHubIssueDeletionLimited, Test-MtCisGitHubStrictBasePermission, Test-MtCisGitHubTeamCreationLimited
}

Describe 'CIS GitHub organization setting tests' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [PSCustomObject]@{
                Connected    = $true
                Organization = 'myorg'
                ApiBaseUri   = 'https://api.github.com'
                ApiVersion   = '2022-11-28'
            }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer faketoken' }
            $__MtSession.GitHubCache      = @{}
            $__MtSession.MaesterConfig    = [PSCustomObject]@{ GlobalSettings = [PSCustomObject]@{} }
        }

        $script:orgResponse = [PSCustomObject]@{
            id                                       = 1001
            login                                    = 'myorg'
            members_can_create_public_repositories  = $false
            members_can_create_private_repositories = $false
            members_can_create_internal_repositories = $false
            members_allowed_repository_creation_type = 'none'
            members_can_delete_repositories         = $false
            members_can_delete_issues               = $false
            members_can_create_teams                = $false
            default_repository_permission           = 'read'
        }

        Mock Invoke-MtGitHubRequest -ModuleName Maester {
            if ($IncludeMetadata) {
                return [pscustomobject]@{ Data = $script:orgResponse; ContentKind = 'Object'; CollectionIntegrityValid = $true; PaginationComplete = $false; Issues = @() }
            }
            $script:orgResponse
        }
        Mock Add-MtTestResultDetail -ModuleName Maester { }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
            $__MtSession.MaesterConfig    = $null
        }
    }

    Context 'Helpers' {
        It 'Test-MtGitHubObjectProperty treats a $false property as present' {
            InModuleScope Maester {
                $obj = [PSCustomObject]@{ members_can_delete_issues = $false }
                Test-MtGitHubObjectProperty -InputObject $obj -PropertyName 'members_can_delete_issues' | Should -BeTrue
                Test-MtGitHubObjectProperty -InputObject $obj -PropertyName 'missing_field' | Should -BeFalse
            }
        }

        It 'Get-MtGitHubOrganization uses the connected organization and request cache helper' {
            InModuleScope Maester {
                $result = Get-MtGitHubOrganization
                $result.login | Should -Be 'myorg'
            }
            Should -Invoke Invoke-MtGitHubRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $RelativeUri -eq '/orgs/myorg'
            }
        }

        It 'Get-MtGitHubOrganization throws when GitHub is not connected' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = $null
                { Get-MtGitHubOrganization } | Should -Throw -ExpectedMessage 'Not connected to GitHub. Call Connect-MtGitHub first.'
            }
        }
    }

    Context 'Pass cases' {
        It 'Passes repository creation when API evidence is compliant' {
            Test-MtCisGitHubRepositoryCreationLimited | Should -BeTrue
        }

        It 'Passes team creation when API evidence is compliant' {
            Test-MtCisGitHubTeamCreationLimited | Should -BeTrue
        }

        It 'Passes strict base permissions when API evidence is compliant' {
            Test-MtCisGitHubStrictBasePermission | Should -BeTrue
        }

        It 'Passes repository creation when the internal repository field is not returned' {
            $script:orgResponse = [PSCustomObject]@{
                members_can_create_public_repositories  = $false
                members_can_create_private_repositories = $false
            }

            Test-MtCisGitHubRepositoryCreationLimited | Should -BeTrue
        }

        It 'Passes repository creation when only returned internal repository creation is allowed' {
            $script:orgResponse.members_can_create_internal_repositories = $true

            Test-MtCisGitHubRepositoryCreationLimited | Should -BeTrue
        }

        It 'Passes when GitHub returns mixed-case Read because -contains is case-insensitive' {
            # This documents PowerShell's default case-insensitive -contains behavior.
            $script:orgResponse.default_repository_permission = 'Read'

            Test-MtCisGitHubStrictBasePermission | Should -BeTrue
        }
    }

    Context 'Result rendering' {
        $renderingCases = @(
            @{
                Function        = 'Test-MtCisGitHubRepositoryCreationLimited'
                Id              = 'CIS.GH.1.2.2'
                ExpectedRows    = @(
                    '\| `members_can_create_public_repositories` \| `False` \| `False` \|'
                    '\| `members_can_create_private_repositories` \| `False` \| `False` \|'
                    '\| `members_can_create_internal_repositories` \| `False` \| `Informational` \|'
                )
                HasLegacyFooter = $true
                HasInternalNote = $true
                IsInvestigate   = $false
            }
            @{
                Function        = 'Test-MtCisGitHubTeamCreationLimited'
                Id              = 'CIS.GH.1.3.2'
                ExpectedRows    = @('\| `members_can_create_teams` \| `False` \| `False` \|')
                HasLegacyFooter = $false
                HasInternalNote = $false
                IsInvestigate   = $false
            }
            @{
                Function        = 'Test-MtCisGitHubStrictBasePermission'
                Id              = 'CIS.GH.1.3.8'
                ExpectedRows    = @('\| `default_repository_permission` \| `read` \| `none` or `read` \|')
                HasLegacyFooter = $false
                HasInternalNote = $false
                IsInvestigate   = $false
            }
        )

        It 'Renders <Function> with the common evidence table shape' -ForEach $renderingCases {
            $functionResult = & $Function
            if ($IsInvestigate) {
                $functionResult | Should -BeNullOrEmpty
            } else {
                $functionResult | Should -BeTrue
            }

            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $Result -match "$Id automated evidence from ``GET /orgs/\{org\}``\." -and
                (($IsInvestigate -and $Result -match '\| Field \| Actual \|' -and $Result -notmatch '\| Expected \|') -or
                    (-not $IsInvestigate -and $Result -match '\| Field \| Actual \| Expected \|')) -and
                (($IsInvestigate -and $Result -match '\| --- \| --- \|') -or
                    (-not $IsInvestigate -and $Result -match '\| --- \| --- \| --- \|')) -and
                (($IsInvestigate -and $Investigate -eq $true) -or (-not $IsInvestigate -and -not $Investigate))
            }

            foreach ($row in $ExpectedRows) {
                Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                    $Result -match $row
                }
            }

            if ($HasLegacyFooter) {
                Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                    $Result -match 'Deprecated umbrella field `members_allowed_repository_creation_type` was returned as `none`' -and
                    $Result -match 'granular fields above are the decisive checks'
                }
            } else {
                Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                    $Result -notmatch 'Deprecated umbrella field'
                }
            }

            if ($HasInternalNote) {
                Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                    $Result -match "The internal-repository row is informational\. CIS GH 1\.2\.2's literal audit covers public and private only\."
                }
            }
        }

        It 'Renders repository creation deprecated umbrella footer when the umbrella field is omitted' {
            $script:orgResponse = [PSCustomObject]@{
                login                                    = 'myorg'
                members_can_create_public_repositories  = $false
                members_can_create_private_repositories = $false
            }

            Test-MtCisGitHubRepositoryCreationLimited | Should -BeTrue

            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $Result -match '\| `members_can_create_public_repositories` \| `False` \| `False` \|' -and
                $Result -match '\| `members_can_create_private_repositories` \| `False` \| `False` \|' -and
                $Result -match 'Deprecated umbrella field `members_allowed_repository_creation_type` was not returned' -and
                $Result -match 'granular fields above are the decisive checks'
            }
        }
    }

    Context 'Fail cases' {
        $failCases = @(
            @{
                Name     = 'repository creation when public repository creation is allowed'
                Function = 'Test-MtCisGitHubRepositoryCreationLimited'
                Mutate   = { $script:orgResponse.members_can_create_public_repositories = $true }
            }
            @{
                Name     = 'team creation when member team creation is allowed'
                Function = 'Test-MtCisGitHubTeamCreationLimited'
                Mutate   = { $script:orgResponse.members_can_create_teams = $true }
            }
            @{
                Name     = 'strict base permissions when default permission is write'
                Function = 'Test-MtCisGitHubStrictBasePermission'
                Mutate   = { $script:orgResponse.default_repository_permission = 'write' }
            }
        )

        It 'Fails <Name>' -ForEach $failCases {
            & $Mutate
            & $Function | Should -BeFalse
        }

    }

    Context 'Missing evidence' {
        $missingFieldCases = @(
            @{
                Function = 'Test-MtCisGitHubRepositoryCreationLimited'
                Field    = 'members_can_create_public_repositories'
            }
            @{
                Function = 'Test-MtCisGitHubRepositoryDeletionLimited'
                Field    = 'members_can_delete_repositories'
            }
            @{
                Function = 'Test-MtCisGitHubIssueDeletionLimited'
                Field    = 'members_can_delete_issues'
            }
            @{
                Function = 'Test-MtCisGitHubTeamCreationLimited'
                Field    = 'members_can_create_teams'
            }
            @{
                Function = 'Test-MtCisGitHubStrictBasePermission'
                Field    = 'default_repository_permission'
            }
        )

        It 'Skips <Function> when <Field> is missing' -ForEach $missingFieldCases {
            $script:orgResponse = [PSCustomObject]@{ login = 'myorg' }

            & $Function | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match $Field
            }
        }
    }

    Context 'Disconnected GitHub' {
        # Native tests: the engine gates on Service = 'GitHub'; the functions no longer guard themselves.
        $nativeCases = @(
            @{ Function = 'Test-MtCisGitHubRepositoryCreationLimited'; Id = 'CIS.GH.1.2.2' }
            @{ Function = 'Test-MtCisGitHubRepositoryDeletionLimited'; Id = 'CIS.GH.1.2.3' }
            @{ Function = 'Test-MtCisGitHubIssueDeletionLimited'; Id = 'CIS.GH.1.2.4' }
            @{ Function = 'Test-MtCisGitHubTeamCreationLimited'; Id = 'CIS.GH.1.3.2' }
            @{ Function = 'Test-MtCisGitHubStrictBasePermission'; Id = 'CIS.GH.1.3.8' }
        )

        It 'Declares GitHub so the engine skips <Id> when GitHub is not connected' -ForEach $nativeCases {
            (Get-MtTest -Id $Id).Service | Should -Contain 'GitHub'

            InModuleScope Maester {
                $__MtSession.GitHubConnection = $null
            }

            $row = Invoke-MtTest -Id $Id
            $row.Result | Should -Be 'Skipped'
            $row.ReasonCode | Should -Be 'ServiceNotConnected'
            Should -Invoke Invoke-MtGitHubRequest -ModuleName Maester -Exactly -Times 0
        }

        It 'Throws from <Function> when called directly without a GitHub connection' -ForEach $nativeCases {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = $null
            }

            { & $Function } | Should -Throw -ExpectedMessage 'Not connected to GitHub. Call Connect-MtGitHub first.'
            Should -Invoke Invoke-MtGitHubRequest -ModuleName Maester -Exactly -Times 0
        }
    }

    Context 'GitHub request errors' {
        $nativeCases = @(
            @{ Function = 'Test-MtCisGitHubRepositoryCreationLimited'; Id = 'CIS.GH.1.2.2' }
            @{ Function = 'Test-MtCisGitHubRepositoryDeletionLimited'; Id = 'CIS.GH.1.2.3' }
            @{ Function = 'Test-MtCisGitHubIssueDeletionLimited'; Id = 'CIS.GH.1.2.4' }
            @{ Function = 'Test-MtCisGitHubTeamCreationLimited'; Id = 'CIS.GH.1.3.2' }
            @{ Function = 'Test-MtCisGitHubStrictBasePermission'; Id = 'CIS.GH.1.3.8' }
        )

        It 'Records <Id> as an error when the GitHub organization request throws' -ForEach $nativeCases {
            Mock Invoke-MtGitHubRequest -ModuleName Maester { throw 'GitHub API boom' }

            { & $Function } | Should -Throw -ExpectedMessage 'GitHub API boom'
            $row = Invoke-MtTest -Id $Id
            $row.Result | Should -Be 'Error'
            $row.ReasonCode | Should -Be 'TestError'
        }
    }
}

Describe 'CIS GitHub evidence through the native transport and parser path' {
    BeforeAll {
        $script:validBody = '{"id":1001,"login":"synthetic-org","members_can_create_public_repositories":false,"members_can_create_private_repositories":false,"members_can_create_internal_repositories":false,"members_can_delete_repositories":false,"members_can_delete_issues":false,"members_can_create_teams":false,"default_repository_permission":"read"}'
    }

    BeforeEach {
        $script:rawBody = $script:validBody
        $script:expectedUri = 'https://api.github.com/orgs/synthetic-org'
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [PSCustomObject]@{
                Connected = $true
                Organization = 'synthetic-org'
                ApiBaseUri = 'https://api.github.com'
                ApiVersion = '2026-03-10'
            }
            $__MtSession.GitHubAuthHeader = @{ 'X-GitHub-Api-Version' = '2026-03-10' }
            $__MtSession.GitHubCache = @{}
        }
        # Only replace transport: real JSON parsing, request cache, native check and result collector run.
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Method -ne 'GET') { throw 'Unexpected transport method blocked by fixture.' }
            if ($Uri -eq "$script:expectedUri/members?role=admin&per_page=100") {
                return [PSCustomObject]@{ Content = '[{"id":11,"login":"synthetic-owner"}]'; Headers = @{} }
            }
            if ($Uri -ne $script:expectedUri) {
                throw 'Unexpected transport request blocked by fixture.'
            }
            [PSCustomObject]@{ Content = $script:rawBody; Headers = @{} }
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache = @{}
            $__MtSession.MaesterConfig = $null
        }
    }

    $checkCases = @(
        @{ Id = 'CIS.GH.1.2.2' }
        @{ Id = 'CIS.GH.1.2.3' }
        @{ Id = 'CIS.GH.1.2.4' }
        @{ Id = 'CIS.GH.1.3.2' }
        @{ Id = 'CIS.GH.1.3.8' }
    )

    It 'Discovers exactly the five intended valid native checks' {
        $expected = @('CIS.GH.1.2.2', 'CIS.GH.1.2.3', 'CIS.GH.1.2.4', 'CIS.GH.1.3.2', 'CIS.GH.1.3.8')
        $actual = @(Get-MtTest -Id 'CIS.GH.*')
        $actual.Count | Should -Be 5
        Compare-Object ($expected | Sort-Object) ($actual.Id | Sort-Object) | Should -BeNullOrEmpty
        foreach ($test in $actual) {
            $test.IsValid | Should -BeTrue
            $test.Errors | Should -BeNullOrEmpty
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0 -Exactly
    }

    Context 'Known configuration evidence' {
        $creationCases = foreach ($public in $false, $true) {
            foreach ($private in $false, $true) {
                @{ Public = $public; Private = $private; Expected = $(if ($public -or $private) { 'Failed' } else { 'Passed' }) }
            }
        }
        It 'Evaluates public=<Public>, private=<Private> independently of the deprecated umbrella field' -ForEach $creationCases {
            $script:rawBody = '{"members_can_create_public_repositories":' + "$Public".ToLowerInvariant() + ',"members_can_create_private_repositories":' + "$Private".ToLowerInvariant() + ',"members_allowed_repository_creation_type":"' + $(if ($Expected -eq 'Passed') { 'all' } else { 'none' }) + '"}'
            $row = @(Invoke-MtTest -Id 'CIS.GH.1.2.2')
            $row.Count | Should -Be 1
            $row[0].Result | Should -Be $Expected
        }

        It 'Keeps internal creation informational when it is <Internal>' -ForEach @(@{ Internal = 'true' }, @{ Internal = 'false' }) {
            $script:rawBody = $script:validBody.Replace('"members_can_create_internal_repositories":false', '"members_can_create_internal_repositories":' + $Internal)
            (Invoke-MtTest -Id 'CIS.GH.1.2.2').Result | Should -Be 'Passed'
        }

        It 'Evaluates team creation <Json> as <Expected>' -ForEach @(
            @{ Json = 'false'; Expected = 'Passed' }
            @{ Json = 'true'; Expected = 'Failed' }
        ) {
            $script:rawBody = '{"members_can_create_teams":' + $Json + '}'
            (Invoke-MtTest -Id 'CIS.GH.1.3.2').Result | Should -Be $Expected
        }

        It 'Evaluates base permission <Value> as <Expected>' -ForEach @(
            @{ Value = 'none'; Expected = 'Passed' }
            @{ Value = 'read'; Expected = 'Passed' }
            @{ Value = 'Read'; Expected = 'Passed' }
            @{ Value = 'write'; Expected = 'Failed' }
            @{ Value = 'admin'; Expected = 'Failed' }
        ) {
            $script:rawBody = '{"default_repository_permission":"' + $Value + '"}'
            (Invoke-MtTest -Id 'CIS.GH.1.3.8').Result | Should -Be $Expected
        }
    }

    Context 'Deletion approval configuration is absent' {
        $deletionCases = foreach ($check in @(
                @{ Id = 'CIS.GH.1.2.3'; Field = 'members_can_delete_repositories' }
                @{ Id = 'CIS.GH.1.2.4'; Field = 'members_can_delete_issues' }
            )) {
            foreach ($value in 'true', 'false') { @{ Id = $check.Id; Field = $check.Field; Json = $value } }
        }
        It 'Keeps <Id> Investigate for <Json> until approval configuration is supplied' -ForEach $deletionCases {
            $script:rawBody = '{"id":1001,"login":"synthetic-org","' + $Field + '":' + $Json + '}'
            $row = @(Invoke-MtTest -Id $Id)
            $row.Count | Should -Be 1
            $row[0].Result | Should -Be 'Investigate'
            $detail = $row[0].ResultDetail.TestResult
            $detail | Should -Match 'GitHubDeletionPolicy'
            $detail | Should -Match 'trusted and qualified'
            $detail | Should -Match $Field
            $detail | Should -Match $Json
            if ($Json -eq 'false') {
                $detail.Contains('| synthetic-owner | 11 | Not configured |') | Should -BeTrue
                Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -Exactly
            } else {
                Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -Exactly
            }
        }
    }

    Context 'Unusable field evidence is indeterminate' {
        $booleanCases = foreach ($check in @(
                @{ Id = 'CIS.GH.1.2.2'; Field = 'members_can_create_public_repositories' }
                @{ Id = 'CIS.GH.1.2.2'; Field = 'members_can_create_private_repositories' }
                @{ Id = 'CIS.GH.1.2.3'; Field = 'members_can_delete_repositories' }
                @{ Id = 'CIS.GH.1.2.4'; Field = 'members_can_delete_issues' }
                @{ Id = 'CIS.GH.1.3.2'; Field = 'members_can_create_teams' }
            )) {
            # These invalid values are defensive fixtures, not documented GitHub Boolean contracts.
            foreach ($json in 'null', '"false"', '0', '[]', '[false]', '{}') {
                @{ Id = $check.Id; Field = $check.Field; Json = $json }
            }
        }
        It 'Skips <Id> when <Field> contains unusable <Json>' -ForEach $booleanCases {
            $script:rawBody = $script:validBody.Replace('"' + $Field + '":false', '"' + $Field + '":' + $Json)
            $row = @(Invoke-MtTest -Id $Id)
            $row.Count | Should -Be 1
            $row[0].Result | Should -Be 'Skipped'
            $row[0].ReasonCode | Should -Be 'TestSkipped'
            $row[0].ReasonDetail | Should -Match 'Indeterminate'
            $row[0].ReasonDetail | Should -Match $Field
        }

        It 'Skips nullable or unrecognized base permission <Json>' -ForEach @(
            @{ Json = 'null' }
            @{ Json = '""' }
            @{ Json = '" "' }
            @{ Json = '"unknown-permission"' }
            @{ Json = 'false' }
            @{ Json = '0' }
            @{ Json = '["read"]' }
            @{ Json = '{}' }
        ) {
            $script:rawBody = '{"default_repository_permission":' + $Json + '}'
            $row = Invoke-MtTest -Id 'CIS.GH.1.3.8'
            $row.Result | Should -Be 'Skipped'
            $row.ReasonCode | Should -Be 'TestSkipped'
            $row.ReasonDetail | Should -Match 'Indeterminate'
            $row.ReasonDetail | Should -Match 'default_repository_permission'
            $row.ReasonDetail | Should -Not -Match 'unknown-permission'
        }

        It 'Skips <Id> for missing required organization evidence' -ForEach $checkCases {
            $script:rawBody = '{}'
            $row = Invoke-MtTest -Id $Id
            $row.Result | Should -Be 'Skipped'
            $row.ReasonCode | Should -Be 'TestSkipped'
            $row.ReasonDetail | Should -Match 'Indeterminate'
        }
    }

    Context 'Shapes still visible after existing normalization' {
        $shapeCases = foreach ($check in $checkCases) {
            foreach ($body in '', 'null', '[]', 'false', '0', '"text"', '[{},{}]') {
                @{ Id = $check.Id; Body = $body }
            }
        }
        It 'Skips <Id> for unusable response body <Body>' -ForEach $shapeCases {
            $script:rawBody = $Body
            $row = Invoke-MtTest -Id $Id
            $row.Result | Should -Be 'Skipped'
            $row.ReasonCode | Should -Be 'TestSkipped'
            $row.ReasonDetail | Should -Match 'Indeterminate'
        }
    }

    It 'Requires both public and private evidence when only <Field> is returned' -ForEach @(
        @{ Field = 'members_can_create_public_repositories' }
        @{ Field = 'members_can_create_private_repositories' }
    ) {
        $script:rawBody = '{"' + $Field + '":false}'
        $row = Invoke-MtTest -Id 'CIS.GH.1.2.2'
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'TestSkipped'
        $row.ReasonDetail | Should -Match 'Indeterminate'
    }


    It 'Fails creation when Boolean true is decisive despite an unusable companion (<Field>, <Companion>)' -ForEach @(
        foreach ($field in 'members_can_create_public_repositories', 'members_can_create_private_repositories') {
            foreach ($companion in 'missing', 'null', '"false"', '0', '{}') { @{ Field = $field; Companion = $companion } }
        }
    ) {
        $other = if ($Field -eq 'members_can_create_public_repositories') { 'members_can_create_private_repositories' } else { 'members_can_create_public_repositories' }
        $script:rawBody = '{"' + $Field + '":true' + $(if ($Companion -ne 'missing') { ',"' + $other + '":' + $Companion }) + '}'
        $row = Invoke-MtTest -Id 'CIS.GH.1.2.2'
        $row.Result | Should -Be 'Failed'
        $row.ResultDetail.TestResult | Should -Match 'True'
        $row.ResultDetail.TestResult | Should -Match 'Unavailable'
    }

    It 'Uses check-visible evidence on configured host <BaseUri>, with missing fields still indeterminate' -ForEach @(
        @{ BaseUri = 'https://api.github.com' }
        @{ BaseUri = 'https://api.synthetic.ghe.com' }
    ) {
        # A synthetic connected session tests request routing, not device-flow or live-platform qualification.
        InModuleScope Maester -Parameters @{ BaseUri = $BaseUri } {
            $__MtSession.GitHubConnection.ApiBaseUri = $BaseUri
        }
        $script:expectedUri = "$BaseUri/orgs/synthetic-org"
        (Invoke-MtTest -Id 'CIS.GH.1.2.2').Result | Should -Be 'Passed'
        InModuleScope Maester { $__MtSession.GitHubCache = @{} }
        $script:rawBody = '{"members_can_create_private_repositories":false}'
        $row = Invoke-MtTest -Id 'CIS.GH.1.2.2'
        $row.Result | Should -Be 'Skipped'
        $row.ReasonDetail | Should -Match 'Indeterminate'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -Exactly
    }

    Context 'Existing singleton-array normalization limitation (characterization only)' {
        # Array-wrapped organization objects are NOT an endorsed GitHub response contract.
        # Current parsing/pipeline enumeration can erase their wrappers before a check sees them.
        # Future parser rejection is allowed: these fixtures must not require preserving that limitation.
        It 'Characterizes an array wrapper without promising complete raw-schema validation: <Wrapper>' -ForEach @(
            @{ Wrapper = 'single' }
            @{ Wrapper = 'nested' }
        ) {
            $script:rawBody = if ($Wrapper -eq 'single') { '[' + $script:validBody + ']' } else { '[[' + $script:validBody + ']]' }
            $row = Invoke-MtTest -Id 'CIS.GH.1.3.2'
            $row.Result | Should -BeIn @('Passed', 'Skipped', 'Error')
            if ($row.Result -eq 'Passed') {
                $parsed = InModuleScope Maester { Get-MtGitHubOrganization }
                ($parsed -is [System.Array]) | Should -BeFalse
                $parsed.members_can_create_teams | Should -BeOfType [bool]
                $parsed.members_can_create_teams | Should -BeFalse
            }
        }
    }

    Context 'Transport and parsing failures retain Error' {
        It 'Reports malformed JSON as Error for <Id>' -ForEach $checkCases {
            $script:rawBody = '{'
            $row = Invoke-MtTest -Id $Id
            $row.Result | Should -Be 'Error'
            $row.ReasonCode | Should -Be 'TestError'
        }

        $httpCases = foreach ($check in $checkCases) {
            foreach ($status in 401, 403, 404, 429, 500, 503) { @{ Id = $check.Id; Status = $status } }
        }
        It 'Reports HTTP <Status> as Error for <Id>' -ForEach $httpCases {
            Mock Invoke-WebRequest -ModuleName Maester {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic GitHub HTTP failure', $response)
            }
            $row = Invoke-MtTest -Id $Id
            $row.Result | Should -Be 'Error'
            $row.ReasonCode | Should -Be 'TestError'
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -Exactly
        }
    }

    It 'Routes requested version <Version> and stores its version-qualified cache key' -ForEach @(
        @{ Version = '2022-11-28' }
        @{ Version = '2026-03-10' }
    ) {
        InModuleScope Maester -Parameters @{ Version = $Version } {
            $__MtSession.GitHubConnection.ApiVersion = $Version
            $__MtSession.GitHubAuthHeader['X-GitHub-Api-Version'] = $Version
        }
        (Invoke-MtTest -Id 'CIS.GH.1.3.2').Result | Should -Be 'Passed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Headers['X-GitHub-Api-Version'] -eq $Version
        }
        InModuleScope Maester -Parameters @{ Version = $Version } {
            $__MtSession.GitHubCache.ContainsKey("$Version|https://api.github.com/orgs/synthetic-org") | Should -BeTrue
        }
    }
}
