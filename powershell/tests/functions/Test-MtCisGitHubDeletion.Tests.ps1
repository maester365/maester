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

    It 'Keeps paginated owner <Failure> failures Error with earlier identities only in result Markdown' -ForEach @(@{ Failure = 'HTTP' }, @{ Failure = 'JSON' }) {
        Mock Invoke-WebRequest -ModuleName Maester {
            param($Uri)
            if ($Uri -like '*page=2') {
                if ($Failure -eq 'JSON') { return @{ Content = '{'; Headers = @{} } }
                throw 'Server text could include sensitive-owner-login.'
            }
            if (([uri]$Uri).AbsolutePath -eq '/orgs/fixture-org') {
                return @{ Content = '{"id":100,"members_can_delete_repositories":false}'; Headers = @{} }
            }
            return @{ Content = '[{"id":1,"login":"retained-owner"},{"id":2}]'; Headers = @{ Link = '<https://api.github.com/orgs/fixture-org/members?role=admin&per_page=100&page=2>; rel="next"' } }
        }
        $row = Invoke-MtTest -Id CIS.GH.1.2.3 -Config $script:nativeConfig
        $row.Result | Should -Be 'Error'
        $row.ReasonCode | Should -Be 'TestError'
        $row.ResultDetail.TestResult | Should -Match 'retained-owner'
        $row.ResultDetail.TestResult | Should -Match '\| 2 \| 3 \|'
        $row.ResultDetail.TestResultRedacted | Should -Not -Match 'retained-owner'
        $row.ReasonDetail | Should -Not -Match 'sensitive-owner-login|retained-owner|GitHubPartialResponse'
        ($row.ErrorRecord | ConvertTo-Json -Depth 50 -Compress) | Should -Not -Match 'sensitive-owner-login|retained-owner|GitHubPartialResponse'
    }

    It 'Keeps complete versus partial native owner verdicts explicit (<Id>, <Partial>)' -ForEach @(
        @{ Id = 'CIS.GH.1.2.3'; Partial = $false }, @{ Id = 'CIS.GH.1.2.4'; Partial = $false },
        @{ Id = 'CIS.GH.1.2.3'; Partial = $true }, @{ Id = 'CIS.GH.1.2.4'; Partial = $true }
    ) {
        Mock Invoke-WebRequest -ModuleName Maester {
            param($Uri)
            if (([uri]$Uri).AbsolutePath -eq '/orgs/fixture-org') {
                return @{ Content = '{"id":100,"members_can_delete_repositories":false,"members_can_delete_issues":false}'; Headers = @{} }
            }
            return @{ Content = '[{"id":1},{"id":2}]'; Headers = $(if ($Partial) { @{ 'X-GitHub-SSO' = 'partial-results' } } else { @{} }) }
        }
        $row = Invoke-MtTest -Id $Id -Config $script:nativeConfig
        $row.Result | Should -Be $(if ($Partial) { 'Skipped' } else { 'Passed' })
        $row.ResultDetail.TestResult | Should -Match '\| 2 \| 3 \|'
    }

    It 'Rejects a nonpositive maximum through native parameter binding' {
        $row = Invoke-MtTest -Id CIS.GH.1.2.3 -Config $script:nativeConfig -Parameter @{ MaximumOrganizationOwners = 0 }
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
            '/orgs/fixture-org/members?role=admin&per_page=100' = @(@{ id = 1; login = 'fixture-owner-one' }, @{ id = 2; login = 'fixture-owner-two' })
            '/orgs/fixture-org/repos?type=all&per_page=100' = @(@{ id = 200; name = 'fixture-repo'; full_name = 'fixture-org/fixture-repo'; owner = @{ login = 'fixture-org' } })
            '/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100' = @(@{ id = 1; permissions = @{ admin = $true } }, @{ id = 2; permissions = @{ admin = $true } }, @{ id = 3; permissions = @{ admin = $false } })
            '/orgs/fixture-org/custom-repository-roles' = @{ total_count = 0; custom_roles = @() }
            '/orgs/fixture-org/organization-roles' = @{ total_count = 0; roles = @() }
        }
        $script:graph = @{ data = @{ repository = @{ databaseId = 200; rulesets = @{ totalCount = 0; nodes = @(); pageInfo = @{ hasNextPage = $false; endCursor = $null } } } } }
        $script:links = @{}
        $script:partialSso = $false
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
            return @{ Content = $content; Headers = $(if ($script:partialSso -and $path -ne '/orgs/fixture-org') { @{ 'X-GitHub-SSO' = 'partial-results' } } elseif ($script:links.ContainsKey($path)) { @{ Link = $script:links[$path] } } else { @{} }) }
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
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result.Contains('| Unavailable | 4 | Not approved |') -and $Result -notmatch '999' }
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
        @{ Case = 'empty owner list'; Policy = @{ ApiBaseUri = 'https://api.github.com'; OrganizationId = '100'; ApprovedOwnerIds = @() } },
        @{ Case = 'missing owner list'; Policy = @{ ApiBaseUri = 'https://api.github.com'; OrganizationId = '100' } }
    ) {
        Set-DeletionPolicy ($Policy | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter {
            $Investigate -and $Result.Contains('| fixture-owner-one | 1 | Not configured |') -and
            $Result.Contains('| fixture-owner-two | 2 | Not configured |') -and $Result -notmatch '999'
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Uri -like '*/members?*' }
    }
    It 'Lists every observed owner with configured approval status for both deletion checks' {
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] += @{ id = 4; login = 'fixture-unapproved' }
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeFalse
        Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 2 -ParameterFilter {
            -not $Investigate -and $Result.Contains('| fixture-owner-one | 1 | Approved |') -and
            $Result.Contains('| fixture-owner-two | 2 | Approved |') -and
            $Result.Contains('| fixture-unapproved | 4 | Not approved |') -and $Result -notmatch '999'
        }
    }
    It 'Escapes owner logins as untrusted result markdown' {
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = @(@{ id = 1; login = "[owner](https://example.invalid)`n| forged" })
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter {
            $Result.Contains('| \[owner\]\(https://example.invalid\) \| forged | 1 | Approved |') -and
            -not $Result.Contains("`n| forged")
        }
    }
    It 'Retains a usable owner ID when the optional login is unavailable' {
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = @(@{ id = 1 })
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '\| [^|]+ \| 1 \| Approved \|' }
    }
    It 'Does not present unavailable owner evidence as an empty complete roster when approvals are missing' {
        Set-DeletionPolicy $null
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = $null
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match 'Indeterminate' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 0 -ParameterFilter { $Investigate }
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
    It 'Retains a confirmed count violation despite a <Gap> (<Kind>)' -ForEach @(
        @{ Gap = 'missing completeness declaration'; Kind = 'Issue' }, @{ Gap = 'missing completeness declaration'; Kind = 'Repository' },
        @{ Gap = 'stale repository declaration'; Kind = 'Issue' }, @{ Gap = 'stale repository declaration'; Kind = 'Repository' },
        @{ Gap = 'undeclared repository'; Kind = 'Issue' }, @{ Gap = 'undeclared repository'; Kind = 'Repository' }
    ) {
        $script:organization.members_can_delete_issues = $true
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        switch ($Gap) {
            'missing policy' { $script:policy = $null }
            'missing completeness declaration' { $script:policy.PSObject.Properties.Remove('CompleteRepositoryInventory') }
            'missing repository declarations' { $script:policy.PSObject.Properties.Remove('Repositories') }
            'stale repository declaration' { $script:policy.Repositories += [pscustomobject]@{ Id = '201'; ApprovedAdministratorIds = @('1', '2') } }
            'empty approval roster' { $script:policy.Repositories[0].ApprovedAdministratorIds = @() }
            'undeclared repository' {
                $script:responses['/orgs/fixture-org/repos?type=all&per_page=100'] += @{ id = 201; name = 'other-repo'; full_name = 'fixture-org/other-repo'; owner = @{ login = 'fixture-org' } }
                $script:responses['/repos/fixture-org/other-repo/collaborators?affiliation=all&per_page=100'] = @(@{ id = 1; permissions = @{ admin = $true } }, @{ id = 2; permissions = @{ admin = $true } })
            }
        }
        Set-DeletionPolicy $script:policy
        $function = if ($Kind -eq 'Issue') { 'Test-MtCisGitHubIssueDeletionLimited' } else { 'Test-MtCisGitHubRepositoryDeletionLimited' }
        $actual = & $function
        $actual | Should -BeOfType ([bool])
        $actual | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { -not $Investigate -and -not $SkippedBecause -and $Result -match '\| fixture-repo \| 3 \|' -and $Result -match '(?i)configure|declar|do not match' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Uri -like '*/fixture-repo/collaborators*' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times $(if ($Kind -eq 'Repository') { 1 } else { 0 }) -ParameterFilter { $Uri -like '*/graphql' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0 -ParameterFilter { $Uri -match 'custom-repository-roles|organization-roles' }
    }
    It 'Reports missing approvals without treating observed administrators as unapproved (<Missing>, <Kind>)' -ForEach @(
        @{ Missing = 'policy'; Kind = 'Issue' }, @{ Missing = 'policy'; Kind = 'Repository' },
        @{ Missing = 'repository'; Kind = 'Issue' }, @{ Missing = 'repository'; Kind = 'Repository' },
        @{ Missing = 'roster'; Kind = 'Issue' }, @{ Missing = 'roster'; Kind = 'Repository' }
    ) {
        $script:organization.members_can_delete_issues = $true
        $script:organization.members_can_delete_repositories = $true
        switch ($Missing) {
            'policy' { $script:policy = $null }
            'repository' { $script:policy.Repositories = @() }
            'roster' { $script:policy.Repositories[0].ApprovedAdministratorIds = @() }
        }
        Set-DeletionPolicy $script:policy
        $function = if ($Kind -eq 'Issue') { 'Test-MtCisGitHubIssueDeletionLimited' } else { 'Test-MtCisGitHubRepositoryDeletionLimited' }
        & $function | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $Investigate -and $Result -match '\| fixture-repo \| Not assessed \| Not configured \|  \| Not assessed \| Not collected \|' -and
            $Result -notmatch 'Meets baseline' -and $RedactedResult -match '\| fixture-repo \| Not assessed \| Not configured \|'
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0 -ParameterFilter { $Uri -match 'collaborators|custom-repository-roles|organization-roles|graphql' }
    }
    It 'Avoids restrictive-policy reads when no approvals are configured' {
        $script:organization.members_can_delete_repositories = $true
        Set-DeletionPolicy $null
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:graph.data.repository.rulesets.totalCount = 1
        $script:graph.data.repository.rulesets.nodes = @(@{ id = 'policy-1'; target = 'REPOSITORY'; enforcement = 'ACTIVE' })
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match '\| fixture-repo \| Not assessed \|' -and $Result -notmatch 'active repository-target policy' }
    }
    It 'Keeps an unapproved observed administrator decisive despite an unrelated inventory gap' {
        $script:organization.members_can_delete_issues = $true
        $script:policy.Repositories[0].ApprovedAdministratorIds = @('1')
        $script:policy.Repositories += [pscustomobject]@{ Id = '201'; ApprovedAdministratorIds = @('1', '2') }
        Set-DeletionPolicy $script:policy
        $actual = Test-MtCisGitHubIssueDeletionLimited
        $actual | Should -BeOfType ([bool])
        $actual | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { -not $Investigate -and -not $SkippedBecause -and $Result -match '\| fixture-repo \| 2 \| 1 \| 2 \|' -and $Result -match 'do not match' }
    }
    It 'Uses validated repositories from a partial inventory (<Companion>, <Violation>)' -ForEach @(
        @{ Companion = 'malformed'; Violation = $false }, @{ Companion = 'malformed'; Violation = $true },
        @{ Companion = 'duplicate'; Violation = $false }, @{ Companion = 'duplicate'; Violation = $true }
    ) {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/orgs/fixture-org/repos?type=all&per_page=100'] += if ($Companion -eq 'duplicate') { $script:responses['/orgs/fixture-org/repos?type=all&per_page=100'][0] } else { $null }
        if ($Violation) { $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } } }
        $actual = Test-MtCisGitHubIssueDeletionLimited
        if ($Violation) { $actual | Should -BeOfType ([bool]); $actual | Should -BeFalse } else { $actual | Should -BeNullOrEmpty }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match 'Organization repository inventory' -and $Result -match '\| fixture-repo \|' -and [bool]$SkippedBecause -eq (-not $Violation) }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Uri -like '*/fixture-repo/collaborators*' }
    }
    It 'Excludes ambiguous inventory identities while retaining unrelated count violations (<Reverse>)' -ForEach @(@{ Reverse = $false }, @{ Reverse = $true }) {
        $script:organization.members_can_delete_issues = $true
        $repositories = @(
            @{ id = 200; name = 'fixture-repo'; full_name = 'fixture-org/fixture-repo'; owner = @{ login = 'fixture-org' } },
            @{ id = 200; name = 'renamed-repo'; full_name = 'fixture-org/renamed-repo'; owner = @{ login = 'fixture-org' } },
            @{ id = 201; name = 'other-repo'; full_name = 'fixture-org/other-repo'; owner = @{ login = 'fixture-org' } }
        )
        if ($Reverse) { [array]::Reverse($repositories) }
        $script:responses['/orgs/fixture-org/repos?type=all&per_page=100'] = $repositories
        $script:responses['/repos/fixture-org/other-repo/collaborators?affiliation=all&per_page=100'] = @(1..3 | ForEach-Object { @{ id = $_; permissions = @{ admin = $true } } })
        $script:policy.Repositories += [pscustomobject]@{ Id = '201'; ApprovedAdministratorIds = @('1', '2', '3') }
        Set-DeletionPolicy $script:policy
        $actual = Test-MtCisGitHubIssueDeletionLimited
        $actual | Should -BeOfType ([bool])
        $actual | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { -not $Investigate -and -not $SkippedBecause -and $Result -match '\| other-repo \| 3 \| 0 \|' -and $Result -notmatch '\| fixture-repo \|' -and $Result -match 'different repository paths' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0 -ParameterFilter { $Uri -match '/(fixture-repo|renamed-repo)/collaborators' }
    }
    It 'Sanitizes inventory request and parsing errors before any collaborator requests (<Failure>)' -ForEach @(@{ Failure = 'HTTP' }, @{ Failure = 'JSON' }) {
        $script:organization.members_can_delete_issues = $true
        Set-DeletionPolicy $null
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -like '*/orgs/fixture-org/repos?*' } {
            if ($Failure -eq 'JSON') { return @{ Content = '{"sensitive-server-value"'; Headers = @{} } }
            throw 'sensitive-server-value'
        }
        { Test-MtCisGitHubIssueDeletionLimited } | Should -Throw -ExpectedMessage 'GitHub deletion evidence request or JSON parsing failed.'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { -not $Investigate -and -not $SkippedBecause -and $Result -match 'execution error' -and $Result -match 'Configure GlobalSettings.GitHubDeletionPolicy' -and $Result -notmatch 'sensitive-server-value' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 0 -ParameterFilter { $Uri -match 'collaborators|graphql|custom-repository-roles|organization-roles' }
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

    It 'Keeps an excess owner lower bound unassessed with missing approvals (<Gap>)' -ForEach @(
        @{ Gap = 'complete collection' }, @{ Gap = 'malformed row' }, @{ Gap = 'duplicate row' }, @{ Gap = 'partial SSO' }
    ) {
        Set-DeletionPolicy $null
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = @(1..4 | ForEach-Object { @{ id = $_; login = "owner-$_" } })
        if ($Gap -eq 'malformed row') { $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] += $null }
        if ($Gap -eq 'duplicate row') { $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] += @{ id = 1 } }
        if ($Gap -eq 'partial SSO') { $script:partialSso = $true }
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '\| 4 \| 3 \|' -and $Result -notmatch 'within the configured maximum' -and [bool]$Investigate -eq ($Gap -eq 'complete collection') -and [bool]$SkippedBecause -eq ($Gap -ne 'complete collection') }
    }

    It 'Retains a configured excess owner lower bound despite <Gap>' -ForEach @(
        @{ Gap = 'malformed row' }, @{ Gap = 'duplicate row' }, @{ Gap = 'partial SSO' }
    ) {
        $script:policy.ApprovedOwnerIds = @('1', '2', '3', '4')
        Set-DeletionPolicy $script:policy
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = @(1..4 | ForEach-Object { @{ id = $_; login = "owner-$_" } })
        if ($Gap -eq 'malformed row') { $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] += $null }
        if ($Gap -eq 'duplicate row') { $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] += @{ id = 1 } }
        if ($Gap -eq 'partial SSO') { $script:partialSso = $true }
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { -not $Investigate -and -not $SkippedBecause -and $Result -match '\| 4 \| 3 \| 0 \|' }
    }

    It 'Fails an unapproved observed owner despite a malformed companion row' {
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = @(@{ id = 4; login = 'observed-owner' }, @{ id = 'invalid' })
        Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match 'observed-owner' -and $Result -match 'Not approved' -and $Result -match '(?i)incomplete|partial' }
    }

    It 'Retains distinct partial owners without establishing a pass' {
        $script:responses['/orgs/fixture-org/members?role=admin&per_page=100'] = @(@{ id = 1; login = 'observed-owner' }, @{ id = 1; login = 'observed-owner' }, $null)
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' -and $Result -match '\| 1 \| 3 \|' -and $Result -match 'observed-owner' }
    }

    It 'Retains a repository violation with unusable evidence in either order (<Kind>, <Reverse>)' -ForEach @(
        @{ Kind = 'Issue'; Reverse = $false }, @{ Kind = 'Issue'; Reverse = $true },
        @{ Kind = 'Repository'; Reverse = $false }, @{ Kind = 'Repository'; Reverse = $true }
    ) {
        $script:organization.members_can_delete_issues = $true
        $script:organization.members_can_delete_repositories = $true
        $second = @{ id = 201; name = 'other-repo'; full_name = 'fixture-org/other-repo'; owner = @{ login = 'fixture-org' } }
        $repos = @($script:responses['/orgs/fixture-org/repos?type=all&per_page=100'][0], $second)
        if ($Reverse) { [array]::Reverse($repos) }
        $script:responses['/orgs/fixture-org/repos?type=all&per_page=100'] = $repos
        $script:policy.Repositories += [pscustomobject]@{ Id = '201'; ApprovedAdministratorIds = @('1', '2') }
        Set-DeletionPolicy $script:policy
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:responses['/repos/fixture-org/other-repo/collaborators?affiliation=all&per_page=100'] = $null
        $function = if ($Kind -eq 'Issue') { 'Test-MtCisGitHubIssueDeletionLimited' } else { 'Test-MtCisGitHubRepositoryDeletionLimited' }
        & $function | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { -not $Investigate -and -not $SkippedBecause -and $Result -match 'fixture-repo' -and $Result -match 'other-repo' -and $Result -match '(?i)incomplete|partial' }
    }

    It 'Uses distinct validated administrators as lower bounds (<Count>, <Incomplete>)' -ForEach @(
        @{ Count = 1; Incomplete = $false; Expected = $false }, @{ Count = 2; Incomplete = $false; Expected = $true }, @{ Count = 3; Incomplete = $false; Expected = $false },
        @{ Count = 1; Incomplete = $true; Expected = $null }, @{ Count = 2; Incomplete = $true; Expected = $null }, @{ Count = 3; Incomplete = $true; Expected = $false }
    ) {
        $script:organization.members_can_delete_issues = $true
        $script:policy.Repositories[0].ApprovedAdministratorIds = @('1', '2', '3')
        Set-DeletionPolicy $script:policy
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] = @(1..$Count | ForEach-Object { @{ id = $_; permissions = @{ admin = $true } } })
        if ($Incomplete) { $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += $null }
        $actual = Test-MtCisGitHubIssueDeletionLimited
        if ($null -eq $Expected) { $actual | Should -BeNullOrEmpty } else { $actual | Should -Be $Expected }
    }

    It 'Does not classify contradictory duplicate permissions as a decisive administrator' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }, @{ id = 4; permissions = @{ admin = $false } }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' -and $Result -match '\| fixture-repo \| 2 \| 0 \|' }
    }

    It 'Deduplicates matching administrators but retains an excess lower bound' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }, @{ id = 4; permissions = @{ admin = $true } }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '\| fixture-repo \| 3 \| 1 \|' }
    }

    It 'Keeps incomplete excess administrator evidence Skipped when restrictive policy remains unresolved' {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }, $null
        $script:graph.data.repository.rulesets.totalCount = 1
        $script:graph.data.repository.rulesets.nodes = @(@{ id = 'policy-1'; target = 'REPOSITORY'; enforcement = 'ACTIVE' })
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' -and -not $Investigate -and $Result -match 'active repository-target policy' -and $Result -match '\| fixture-repo \| 3 \| 1 \|' }
    }

    It 'Keeps a later HTTP failure as Error while retaining earlier evidence' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/orgs/fixture-org/repos?type=all&per_page=100'] += @{ id = 201; name = 'other-repo'; full_name = 'fixture-org/other-repo'; owner = @{ login = 'fixture-org' } }
        $script:policy.Repositories += [pscustomobject]@{ Id = '201'; ApprovedAdministratorIds = @('1', '2') }
        Set-DeletionPolicy $script:policy
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:ratePath = '/repos/fixture-org/other-repo/collaborators?affiliation=all&per_page=100'
        { Test-MtCisGitHubIssueDeletionLimited } | Should -Throw -ExpectedMessage '*rate limit*'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { -not $Investigate -and -not $SkippedBecause -and $Result -match '\| fixture-repo \| 3 \| 1 \|' -and $Result -match '(?i)execution|request' }
    }


    It 'Keeps exactly two distinct administrators indeterminate when a duplicate prevents completeness' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 1; permissions = @{ admin = $true } }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' -and $Result -match '\| fixture-repo \| 2 \| 0 \|' }
    }

    It 'Preserves excess admins despite malformed permission or identity companions (<Companion>)' -ForEach @(@{ Companion = 'permission' }, @{ Companion = 'identity' }) {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += if ($Companion -eq 'permission') { @{ id = 5; permissions = @{ admin = 'true' } } } else { @{ id = '5'; permissions = @{ admin = $true } } }
        Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '\| fixture-repo \| 3 \| 1 \|' -and $Result -match '(?i)incomplete|partial' }
    }

    It 'Retains only nonconflicting administrator evidence regardless of duplicate order (<Reverse>)' -ForEach @(@{ Reverse = $false }, @{ Reverse = $true }) {
        $script:organization.members_can_delete_issues = $true
        $records = @(@{ id = 1; permissions = @{ admin = $true } }, @{ id = 2; permissions = @{ admin = $true } }, @{ id = 4; permissions = @{ admin = $false } }, @{ id = 4; permissions = @{ admin = $true } }, @{ id = 5; permissions = @{ admin = $true } })
        if ($Reverse) { [array]::Reverse($records) }
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] = $records
        Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '\| fixture-repo \| 3 \| 1 \| 5 \|' }
    }

    It 'Uses the retained owner lower bound at the production pagination cap' {
        Set-DeletionPolicy $null
        Mock Invoke-WebRequest -ModuleName Maester {
            param($Uri)
            if (([uri]$Uri).AbsolutePath -eq '/orgs/fixture-org') {
                return @{ Content = '{"id":100,"members_can_delete_repositories":false}'; Headers = @{} }
            }
            $page = if ($Uri -match '[&?]page=(\d+)') { [int]$Matches[1] } else { 1 }
            return @{ Content = '[{"id":' + $page + '}]'; Headers = @{ Link = '<https://api.github.com/orgs/fixture-org/members?role=admin&per_page=100&page=' + ($page + 1) + '>; rel="next"' } }
        }
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeFalse
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 101
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '\| 100 \| 3 \|' -and $Result -match 'lower bound' }
    }

    It 'Confirms partial repository violations only after usable restrictive-policy evidence' {
        $script:organization.members_can_delete_repositories = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }, $null
        Test-MtCisGitHubRepositoryDeletionLimited | Should -BeFalse
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Uri -like '*/graphql' }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match 'confirmed' -and $Result -match 'lower bound' }
    }


    It 'Distinguishes no administrators in a usable population from an empty collaborator response' {
        $script:organization.members_can_delete_issues = $true
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] = @(@{ id = 1; permissions = @{ admin = $false } })
        Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '\| fixture-repo \| 0 \| 0 \|' -and $Result -match 'Complete' }
    }


    It 'Preserves outcome precedence with coexisting required and policy gaps (<Reverse>, <Confirmed>)' -ForEach @(
        @{ Reverse = $false; Confirmed = $false }, @{ Reverse = $true; Confirmed = $false },
        @{ Reverse = $false; Confirmed = $true }, @{ Reverse = $true; Confirmed = $true }
    ) {
        $script:organization.members_can_delete_repositories = $true
        $repos = @($script:responses['/orgs/fixture-org/repos?type=all&per_page=100'][0], @{ id = 201; name = 'other-repo'; full_name = 'fixture-org/other-repo'; owner = @{ login = 'fixture-org' } })
        $script:policy.Repositories += [pscustomobject]@{ Id = '201'; ApprovedAdministratorIds = @('1', '2') }
        $script:responses['/repos/fixture-org/fixture-repo/collaborators?affiliation=all&per_page=100'] += @{ id = 4; permissions = @{ admin = $true } }
        $script:responses['/repos/fixture-org/other-repo/collaborators?affiliation=all&per_page=100'] = $null
        if ($Confirmed) {
            $repos += @{ id = 202; name = 'confirmed-repo'; full_name = 'fixture-org/confirmed-repo'; owner = @{ login = 'fixture-org' } }
            $script:policy.Repositories += [pscustomobject]@{ Id = '202'; ApprovedAdministratorIds = @('1', '2') }
            $script:responses['/repos/fixture-org/confirmed-repo/collaborators?affiliation=all&per_page=100'] = @(@{ id = 1; permissions = @{ admin = $true } }, @{ id = 2; permissions = @{ admin = $true } }, @{ id = 4; permissions = @{ admin = $true } })
        }
        if ($Reverse) { [array]::Reverse($repos) }
        $script:responses['/orgs/fixture-org/repos?type=all&per_page=100'] = $repos
        Set-DeletionPolicy $script:policy
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { ([uri]$Uri).AbsolutePath -eq '/graphql' } {
            param($Body)
            $request = $Body | ConvertFrom-Json
            $restricted = $request.variables.repo -eq 'fixture-repo'
            $rulesets = @{ totalCount = $(if ($restricted) { 1 } else { 0 }); nodes = @(); pageInfo = @{ hasNextPage = $false; endCursor = $null } }
            if ($restricted) { $rulesets.nodes = @(@{ id = 'policy-1'; target = 'REPOSITORY'; enforcement = 'ACTIVE' }) }
            $response = @{ data = @{ repository = @{ databaseId = $(if ($restricted) { 200 } else { 202 }); rulesets = $rulesets } } }
            return @{ Content = $response | ConvertTo-Json -Depth 30 -Compress; Headers = @{} }
        }
        $actual = Test-MtCisGitHubRepositoryDeletionLimited
        if ($Confirmed) {
            $actual | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { -not $Investigate -and -not $SkippedBecause -and $Result -match 'confirmed-repo' -and $Result -match 'active repository-target policy' -and $Result -match 'other-repo:.*incomplete' }
        } else {
            $actual | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Custom' -and -not $Investigate -and $Result -match 'active repository-target policy' -and $Result -match 'other-repo:.*incomplete' }
        }
    }

}

Describe 'GitHub user pseudonyms' {
    It 'Uses host-scoped stable pseudonyms without replacing numeric facts or Markdown syntax' {
        InModuleScope Maester {
            $evidence = @{
                ApiAuthority = 'https://API.GITHUB.COM:443/'; OwnerBranch = $true; Field = 'members_can_delete_issues'; Setting = $false
                OrganizationId = 2; MaximumOrganizationOwners = 3; Owners = @(@{ id = 2; login = '2' }, @{ id = 3; login = 'a|b`x' })
                ApprovalsConfigured = $true; ApprovedOwnerIds = @('2'); OwnerComplete = $true; Gaps = @(); Message = 'CIS.GH.1.2.3'
            }
            $raw = Get-MtCisGitHubDeletionResult -Evidence $evidence
            $safe = Get-MtCisGitHubDeletionResult -Evidence $evidence -RedactUserIdentity
            $raw | Should -Match ([regex]::Escape((Get-MtSafeMarkdown 'a|b`x')))
            $safe | Should -Not -Match 'a\\?\|b|\| 2 \| 2 \| Approved'
            $safe | Should -Match '\| 2 \| 3 \| 1 \| Complete'
            $safe | Should -Match 'Organization ID: `2`'
            $safe | Should -Match 'CIS.GH.1.2.3'
            $expected = Get-MtAffectedObjectUniqueId -System GitHub -Type User -Id 'https://api.github.com/users/2'
            $safe | Should -Match ([regex]::Escape("| $expected | $expected | Approved |"))
            $evidence.ApiAuthority = 'https://api.fixture.ghe.com'
            $otherHost = Get-MtCisGitHubDeletionResult -Evidence $evidence -RedactUserIdentity
            $otherHost | Should -Not -Match $expected
            $evidence.OwnerBranch = $false
            $evidence.Repositories = @(@{ Name = 'fixture'; AdministratorCount = 3; UnapprovedIds = @('2'); Complete = $false; ApprovalsConfigured = $true; Assessment = 'Needs review' })
            $admin = Get-MtCisGitHubDeletionResult -Evidence $evidence -RedactUserIdentity
            $otherToken = Get-MtAffectedObjectUniqueId -System GitHub -Type User -Id 'https://api.fixture.ghe.com/users/2'
            $otherHost | Should -Match $otherToken
            $admin | Should -Match $otherToken
            $admin | Should -Match '\| fixture \| 3 \| 1 \|'
        }
    }

}
