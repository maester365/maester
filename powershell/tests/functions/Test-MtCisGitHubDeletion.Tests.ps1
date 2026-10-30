BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisGitHubRepositoryDeletionLimited, Test-MtCisGitHubIssueDeletionLimited

    function Set-DeletionPolicy {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper sets synthetic in-memory module state and has no persistent or external side effects.')]
        [CmdletBinding()]
        param([object] $Policy)
        InModuleScope Maester -Parameters @{ Policy = $Policy } {
            $__MtSession.MaesterConfig = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ GitHubDeletionPolicy = $Policy } }
        }
    }
}

Describe 'Deletion results through the native Invoke-MtTest entry point' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer fixture-token' }
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = @{}
        }
        $script:nativeSetting = $false
        $script:nativeHttpError = $false
        $script:nativeConfig = @{ GlobalSettings = @{ GitHubDeletionPolicy = @{ ApiBaseUri = 'https://api.github.com'; OrganizationId = '100'; ApprovedOwnerIds = @('1', '2', '999') } } }
        Mock Invoke-WebRequest -ModuleName Maester {
            param($Uri)
            if ($script:nativeHttpError) { throw 'Fixture HTTP execution failure.' }
            if (([uri]$Uri).AbsolutePath -eq '/orgs/fixture-org') {
                return @{ Content = ConvertTo-Json -InputObject @{ id = 100; members_can_delete_repositories = $script:nativeSetting; members_can_delete_issues = $script:nativeSetting } -Compress; Headers = @{} }
            }
            return @{ Content = '[{"id":1},{"id":2}]'; Headers = @{} }
        }
    }
    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = @{}
            $__MtSession.MaesterConfig = $null
        }
    }
    It 'Produces a mapped Passed row for each approved owner-only branch' {
        $rows = @(Invoke-MtTest -Id CIS.GH.1.2.3, CIS.GH.1.2.4 -Config $script:nativeConfig)
        $rows.Count | Should -Be 2
        foreach ($row in $rows) {
            $row.Result | Should -Be 'Passed'
            $row.Control | Should -Contain ('cis-github:' + $row.Id.Substring(7))
            ($row.Parameters | Where-Object Name -EQ MaximumOrganizationOwners).Value | Should -Be 3
            $row.ResultDetail.TestResult | Should -Not -Match '999'
        }
    }
    It 'Produces Failed for an observed owner outside the approval roster' {
        $script:nativeConfig.GlobalSettings.GitHubDeletionPolicy.ApprovedOwnerIds = @('1')
        (Invoke-MtTest -Id CIS.GH.1.2.3 -Config $script:nativeConfig).Result | Should -Be 'Failed'
    }
    It 'Keeps missing approval configuration Investigate' {
        (Invoke-MtTest -Id CIS.GH.1.2.3 -Config @{ GlobalSettings = @{} }).Result | Should -Be 'Investigate'
    }
    It 'Keeps unusable required evidence Skipped' {
        $script:nativeSetting = $null
        (Invoke-MtTest -Id CIS.GH.1.2.3 -Config $script:nativeConfig).Result | Should -Be 'Skipped'
    }
    It 'Keeps required HTTP execution failure Error' {
        $script:nativeHttpError = $true
        (Invoke-MtTest -Id CIS.GH.1.2.3 -Config $script:nativeConfig).Result | Should -Be 'Error'
    }
    It 'Rejects a maximum above three through native parameter binding' {
        $row = Invoke-MtTest -Id CIS.GH.1.2.3 -Config $script:nativeConfig -Parameter @{ MaximumOrganizationOwners = 4 }
        $row.Result | Should -Be 'Error'
        $row.ReasonCode | Should -Be 'InvalidConfiguration'
    }
    It 'Keeps an unknown custom-role base Investigate through native issue assessment' {
        $script:nativeConfig.GlobalSettings.GitHubDeletionPolicy.CompleteRepositoryInventory = $true
        $script:nativeConfig.GlobalSettings.GitHubDeletionPolicy.Repositories = @(@{ Id = '200'; ApprovedAdministratorIds = @('1', '2') })
        Mock Invoke-WebRequest -ModuleName Maester {
            param($Uri)
            $path = ([uri]$Uri).AbsolutePath
            $content = switch ($path) {
                '/orgs/fixture-org' { '{"id":100,"members_can_delete_issues":true}' }
                '/orgs/fixture-org/repos' { '[{"id":200,"name":"fixture-repo","full_name":"fixture-org/fixture-repo","owner":{"login":"fixture-org"}}]' }
                '/repos/fixture-org/fixture-repo/collaborators' { '[{"id":1,"permissions":{"admin":true}},{"id":2,"permissions":{"admin":true}}]' }
                '/orgs/fixture-org/custom-repository-roles' { '{"total_count":1,"custom_roles":[{"id":10,"base_role":"unknown-role","permissions":[]}]}' }
                default { throw 'Unexpected native role fixture request.' }
            }
            return @{ Content = $content; Headers = @{} }
        }
        $row = Invoke-MtTest -Id CIS.GH.1.2.4 -Config $script:nativeConfig
        $row.Result | Should -Be 'Investigate'
        $row.ResultDetail.TestResult | Should -Match 'unknown base role'
    }
}

Describe 'GitHub CIS deletion assessment through shared HTTP transports' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer fixture-token'; 'X-GitHub-Api-Version' = '2022-11-28' }
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = @{}
        }
        $script:policy = @{
            ApiBaseUri = 'https://api.github.com'; OrganizationId = '100'; ApprovedOwnerIds = @('1', '2', '3', '999')
            CompleteRepositoryInventory = $true
            Repositories = @(@{ Id = '200'; ApprovedAdministratorIds = @('1', '2', '999') })
        } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        Set-DeletionPolicy $script:policy
        $script:organization = @{ id = 100; login = 'fixture-org'; members_can_delete_issues = $false; members_can_delete_repositories = $false }
        $script:responses = @{
            '/orgs/fixture-org/members?role=admin&per_page=100' = @(@{ id = 1 }, @{ id = 2 })
            '/orgs/fixture-org/repos?type=all&per_page=100' = @(@{ id = 200; name = 'fixture-repo'; full_name = 'fixture-org/fixture-repo'; owner = @{ login = 'fixture-org' } })
            '/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100' = @(@{ id = 1; permissions = @{ admin = $true } }, @{ id = 2; permissions = @{ admin = $true } }, @{ id = 3; permissions = @{ admin = $false } })
            '/orgs/fixture-org/custom-repository-roles' = @{ total_count = 0; custom_roles = @() }
            '/orgs/fixture-org/organization-roles' = @{ total_count = 0; roles = @() }
        }
        $script:graph = @{ data = @{ repository = @{ databaseId = 200; rulesets = @{ totalCount = 0; nodes = @(); pageInfo = @{ hasNextPage = $false; endCursor = $null } } } } }
        $script:links = @{}
        $script:ratePath = $null
        Mock Invoke-WebRequest -ModuleName Maester {
            param($Uri, $Method, $Headers, $Body)
            $path = ([uri]$Uri).PathAndQuery
            if ($path -eq $script:ratePath) {
                $exception = [System.Exception]::new('Fixture primary rate limit.')
                Add-Member -InputObject $exception -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 403; Headers = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = '9999999999' } })
                throw $exception
            }
            if ($path -eq '/graphql') {
                if ($Method -ne 'POST' -or $Body -match '\bmutation\b') { throw 'Fixture refuses a non-read operation.' }
                return @{ Content = $script:graph | ConvertTo-Json -Depth 30 -Compress; Headers = @{} }
            }
            if ($Method -ne 'GET' -or $Headers['X-GitHub-Api-Version'] -ne '2026-03-10') { throw 'Fixture requires a pinned read-only REST operation.' }
            if ($path -eq '/orgs/fixture-org') { $value = $script:organization }
            elseif ($script:responses.ContainsKey($path)) { $value = $script:responses[$path] }
            else { throw 'Unexpected fixture request.' }
            # Do not pipe array values: preserve [] and singleton array shapes on the wire.
            $content = ConvertTo-Json -InputObject $value -Depth 30 -Compress
            return @{ Content = $content; Headers = $(if ($script:links.ContainsKey($path)) { @{ Link = $script:links[$path] } } else { @{} }) }
        }
        Mock Add-MtTestResultDetail -ModuleName Maester {}
    }
    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache = @{}
            $__MtSession.GitHubRateLimits = @{}
            $__MtSession.MaesterConfig = $null
        }
    }

    It 'Passes both owner-only branches without repository, custom-role or policy requests' {
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeTrue
        Test-MtCisGitHubIssueDeletionLimited | Should -BeTrue
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 2 -ParameterFilter { $Result -like 'Well done.*' -and $Result -notmatch '999' -and -not $Investigate }
    }
    It 'Counts actual owners rather than the longer approval roster' {
        Test-MtCisGitHubRepositoryDeletionLimited -MaximumOrganizationOwners 2 | Should -BeTrue
        Test-MtCisGitHubRepositoryDeletionLimited -MaximumOrganizationOwners 1 | Should -BeFalse
    }
    It 'Fails a non-approved live owner and identifies only observed IDs' {
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = @(@{ id = 4 })
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match 'owner IDs: 4' -and $Result -notmatch '999' }
    }
    It 'Traverses owner pagination before deciding approval membership' {
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = @(@{ id = 1 })
        $script:links['/orgs/fixture-org/members?role=admin&per_page=100'] = '<https://api.github.com/orgs/fixture-org/members?role=admin&per_page=100&page=2>; rel="next"'
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100&page=2'] = @(@{ id = 4 })
        Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        Should -Invoke Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like '*page=2' }
    }
    It 'Investigates absent or empty approvals (<Case>)' -ForEach @(
        @{ Case = 'missing object'; Policy = $null },
        @{ Case = 'default empty object'; Policy = @{} },
        @{ Case = 'empty owner list'; Policy = @{ ApiBaseUri = 'https://api.github.com'; OrganizationId = '100'; ApprovedOwnerIds = @() } }
    ) {
        Set-DeletionPolicy ($Policy | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }
    It 'Rejects malformed or mismatched policy configuration (<Case>)' -ForEach @(
        @{ Case = 'number instead of ID string'; Key = 'OrganizationId'; Value = 100 },
        @{ Case = 'wrong organization'; Key = 'OrganizationId'; Value = '101' },
        @{ Case = 'wrong host'; Key = 'ApiBaseUri'; Value = 'https://api.fixture.ghe.com' },
        @{ Case = 'duplicate approved ID'; Key = 'ApprovedOwnerIds'; Value = @('1', '1') },
        @{ Case = 'non-Boolean completeness'; Key = 'CompleteRepositoryInventory'; Value = 'true' }
    ) {
        $script:policy.$Key = $Value
        Set-DeletionPolicy $script:policy
        { Test-MtCisGitHubRepositoryDeletionLimited } | Should -Throw
    }
    It 'Skips unusable owner evidence (<Case>)' -ForEach @(
        @{ Case = 'empty'; Owners = @() },
        @{ Case = 'null'; Owners = $null },
        @{ Case = 'object instead of array'; Owners = @{ id = 1 } },
        @{ Case = 'string ID'; Owners = @(@{ id = '1' }) },
        @{ Case = 'duplicate identity'; Owners = @(@{ id = 1 }, @{ id = 1 }) }
    ) {
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = $Owners
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
    It 'Skips missing, null or non-Boolean setting evidence (<Value>)' -ForEach @(@{ Value = $null }, @{ Value = 'false' }, @{ Value = 0 }) {
        $script:organization.members_can_delete_repositories = $Value
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
    It 'Passes the complete two-approved-admin repository baseline without optional policy reads' {
        $script:organization.members_can_delete_repositories = $true
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeTrue
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0 -ParameterFilter { $Uri -like '*/graphql' -or $Uri -like '*roles*' }
    }
    It 'Passes issue baseline only after qualifying both complete custom-role catalogs' {
        $script:organization.members_can_delete_issues = $true
        Test-MtCisGitHubIssueDeletionLimited | Should -BeTrue
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter { $Uri -like '*/custom-repository-roles' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter { $Uri -like '*/organization-roles' }
    }
    It 'Investigates relevant extra issue-deletion permissions' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/orgs/fixture-org/custom-repository-roles'] = @{ total_count = 1; custom_roles = @(@{ id = 10; base_role = 'read'; permissions = @('delete_issue') }) }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'custom role can grant issue deletion' }
    }
    It 'Investigates malformed role catalogs rather than treating them as empty' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/orgs/fixture-org/custom-repository-roles'] = @{ total_count = 1; custom_roles = @() }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'catalog is incomplete' }
    }
    It 'Investigates unusable custom repository base-role semantics (<Base>)' -ForEach @(@{ Base = 'unknown-role' }, @{ Base = $null }, @{ Base = 'admin' }) {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/orgs/fixture-org/custom-repository-roles'] = @{ total_count = 1; custom_roles = @(@{ id = 10; base_role = $Base; permissions = @() }) }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'unknown base role' }
    }
    It 'Investigates unknown organization base-role semantics' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/orgs/fixture-org/organization-roles'] = @{ total_count = 1; roles = @(@{ id = 10; base_role = 'unknown-role'; permissions = @() }) }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'unknown base role' }
    }
    It 'Accepts optional organization base-role representations (<Base>)' -ForEach @(@{ Base = $null }, @{ Base = 'none' }, @{ Base = 'admin' }) {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/orgs/fixture-org/organization-roles'] = @{ total_count = 1; roles = @(@{ id = 10; base_role = $Base; permissions = @() }) }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeTrue
    }
    It 'Accepts a documented custom repository base and an omitted optional organization base' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/orgs/fixture-org/custom-repository-roles'] = @{ total_count = 1; custom_roles = @(@{ id = 10; base_role = 'maintain'; permissions = @() }) }
        $script:responses['/orgs/fixture-org/organization-roles'] = @{ total_count = 1; roles = @(@{ id = 11; permissions = @() }) }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeTrue
    }
    It 'Fails a positive issue admin violation without additive-role or repository-policy requests' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0 -ParameterFilter { $Uri -like '*/graphql' -or $Uri -like '*roles*' }
    }
    It 'Fails repository baseline with complete evidence of no alternative policy' {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeFalse
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter { $Uri -like '*/graphql' }
    }
    It 'Investigates an active repository-target policy before declaring a baseline failure' {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:graph.data.repository.rulesets.totalCount = 1
        $script:graph.data.repository.rulesets.nodes = @(@{ id = 'policy-1'; target = 'REPOSITORY'; enforcement = 'ACTIVE' })
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'fixture-repo: An active repository-target policy' }
    }
    It 'Investigates partial GraphQL responses even when their policy array is empty' {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:graph.errors = @(@{ type = 'INSUFFICIENT_SCOPES' })
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'policy evidence is unavailable' }
    }
    It 'Investigates incomplete repository declarations' {
        $script:organization.members_can_delete_repositories = $true
        $script:policy.Repositories[0].Id = '201'
        Set-DeletionPolicy $script:policy
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'do not match' }
    }
    It 'Skips malformed administrator evidence instead of treating missing admin as false' {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'][0].permissions.admin = $null
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' }
    }
    It 'Skips an unexpectedly empty effective collaborator population' {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] = @()
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match 'unexpectedly empty' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0 -ParameterFilter { $Uri -like '*/graphql' }
    }
    It 'Rejects policy evidence correlated through a string or wrong repository ID (<Id>)' -ForEach @(@{ Id = '200' }, @{ Id = 201 }) {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:graph.data.repository.databaseId = $Id
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'policy evidence is unavailable' }
    }
    It 'Preserves optional-catalog primary HTTP 403 rate limits as execution errors without retries' {
        $script:organization.members_can_delete_issues = $true
        $script:ratePath = '/orgs/fixture-org/custom-repository-roles'
        { Test-MtCisGitHubIssueDeletionLimited } | Should -Throw -ExpectedMessage '*rate limit*'
        { Test-MtCisGitHubIssueDeletionLimited } | Should -Throw -ExpectedMessage '*rate limit*'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { ([uri]$Uri).AbsolutePath -eq '/orgs/fixture-org/custom-repository-roles' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 0 -ParameterFilter { $Investigate }
    }
    It 'Preserves optional-policy primary HTTP 403 rate limits as execution errors without retries' {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:ratePath = '/graphql'
        { Test-MtCisGitHubRepositoryDeletionLimited } | Should -Throw -ExpectedMessage '*rate limit*'
        { Test-MtCisGitHubRepositoryDeletionLimited } | Should -Throw -ExpectedMessage '*rate limit*'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { ([uri]$Uri).AbsolutePath -eq '/graphql' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 0 -ParameterFilter { $Investigate }
    }
}
