BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
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
            login                                    = 'myorg'
            members_can_create_public_repositories  = $false
            members_can_create_private_repositories = $false
            members_can_create_internal_repositories = $false
            members_can_create_repositories         = $false
            members_can_delete_repositories         = $false
            members_can_delete_issues               = $false
            members_can_create_teams                = $false
            default_repository_permission           = 'read'
        }

        Mock Invoke-MtGitHubRequest -ModuleName Maester { $script:orgResponse }
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

        It 'Passes repository deletion when API evidence is compliant' {
            Test-MtCisGitHubRepositoryDeletionLimited | Should -BeTrue
        }

        It 'Passes issue deletion when API evidence is compliant' {
            Test-MtCisGitHubIssueDeletionLimited | Should -BeTrue
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
            }
            @{
                Function        = 'Test-MtCisGitHubRepositoryDeletionLimited'
                Id              = 'CIS.GH.1.2.3'
                ExpectedRows    = @('\| `members_can_delete_repositories` \| `False` \| `False` \|')
                HasLegacyFooter = $false
                HasInternalNote = $false
            }
            @{
                Function        = 'Test-MtCisGitHubIssueDeletionLimited'
                Id              = 'CIS.GH.1.2.4'
                ExpectedRows    = @('\| `members_can_delete_issues` \| `False` \| `False` \|')
                HasLegacyFooter = $false
                HasInternalNote = $false
            }
            @{
                Function        = 'Test-MtCisGitHubTeamCreationLimited'
                Id              = 'CIS.GH.1.3.2'
                ExpectedRows    = @('\| `members_can_create_teams` \| `False` \| `False` \|')
                HasLegacyFooter = $false
                HasInternalNote = $false
            }
            @{
                Function        = 'Test-MtCisGitHubStrictBasePermission'
                Id              = 'CIS.GH.1.3.8'
                ExpectedRows    = @('\| `default_repository_permission` \| `read` \| `none` or `read` \|')
                HasLegacyFooter = $false
                HasInternalNote = $false
            }
        )

        It 'Renders <Function> with the common evidence table shape' -ForEach $renderingCases {
            & $Function | Should -BeTrue

            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $Result -match "$Id automated evidence from ``GET /orgs/\{org\}``\." -and
                $Result -match '\| Field \| Actual \| Expected \|' -and
                $Result -match '\| --- \| --- \| --- \|'
            }

            foreach ($row in $ExpectedRows) {
                Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                    $Result -match $row
                }
            }

            if ($HasLegacyFooter) {
                Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                    $Result -match 'Umbrella legacy field `members_can_create_repositories` was returned as `False`' -and
                    $Result -match 'granular fields above are the decisive checks'
                }
            } else {
                Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                    $Result -notmatch 'Umbrella legacy field'
                }
            }

            if ($HasInternalNote) {
                Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                    $Result -match "The internal-repository row is informational\. CIS GH 1\.2\.2's literal audit covers public and private only\."
                }
            }
        }

        It 'Renders repository creation legacy footer when the umbrella field is omitted' {
            $script:orgResponse = [PSCustomObject]@{
                login                                    = 'myorg'
                members_can_create_public_repositories  = $false
                members_can_create_private_repositories = $false
            }

            Test-MtCisGitHubRepositoryCreationLimited | Should -BeTrue

            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $Result -match '\| `members_can_create_public_repositories` \| `False` \| `False` \|' -and
                $Result -match '\| `members_can_create_private_repositories` \| `False` \| `False` \|' -and
                $Result -match 'Umbrella legacy field `members_can_create_repositories` was not returned' -and
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
                Name     = 'repository deletion when member repository deletion is allowed'
                Function = 'Test-MtCisGitHubRepositoryDeletionLimited'
                Mutate   = { $script:orgResponse.members_can_delete_repositories = $true }
            }
            @{
                Name     = 'issue deletion when member issue deletion is allowed'
                Function = 'Test-MtCisGitHubIssueDeletionLimited'
                Mutate   = { $script:orgResponse.members_can_delete_issues = $true }
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

    Context 'Manual review opt-in' {
        It 'Fails repository deletion by default when member repository deletion is allowed' {
            $script:orgResponse.members_can_delete_repositories = $true

            Test-MtCisGitHubRepositoryDeletionLimited | Should -BeFalse
        }

        It 'Marks repository deletion as investigate when manual review is explicitly allowed' {
            $script:orgResponse.members_can_delete_repositories = $true
            InModuleScope Maester {
                $__MtSession.MaesterConfig.GlobalSettings | Add-Member -MemberType NoteProperty -Name GitHubAllowMemberRepositoryDeletion -Value $true -Force
            }

            Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                -not $SkippedBecause -and
                -not $SkippedCustomReason -and
                $Investigate -eq $true -and
                $Result -match 'Manual review required' -and
                $Result -match 'members_can_delete_repositories' -and
                $Result -match '\| `members_can_delete_repositories` \| `True` \| `False` \|'
            }
        }

        It 'Fails repository deletion when the manual-review config value is not a literal boolean' {
            $script:orgResponse.members_can_delete_repositories = $true
            InModuleScope Maester {
                $__MtSession.MaesterConfig.GlobalSettings | Add-Member -MemberType NoteProperty -Name GitHubAllowMemberRepositoryDeletion -Value 'true' -Force
            }

            Test-MtCisGitHubRepositoryDeletionLimited | Should -BeFalse
        }

        It 'Fails issue deletion by default when member issue deletion is allowed' {
            $script:orgResponse.members_can_delete_issues = $true

            Test-MtCisGitHubIssueDeletionLimited | Should -BeFalse
        }

        It 'Marks issue deletion as investigate when manual review is explicitly allowed' {
            $script:orgResponse.members_can_delete_issues = $true
            InModuleScope Maester {
                $__MtSession.MaesterConfig.GlobalSettings | Add-Member -MemberType NoteProperty -Name GitHubAllowMemberIssueDeletion -Value $true -Force
            }

            Test-MtCisGitHubIssueDeletionLimited | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                -not $SkippedBecause -and
                -not $SkippedCustomReason -and
                $Investigate -eq $true -and
                $Result -match 'Manual review required' -and
                $Result -match 'members_can_delete_issues' -and
                $Result -match '\| `members_can_delete_issues` \| `True` \| `False` \|'
            }
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
        $functions = @(
            'Test-MtCisGitHubRepositoryCreationLimited'
            'Test-MtCisGitHubRepositoryDeletionLimited'
            'Test-MtCisGitHubIssueDeletionLimited'
            'Test-MtCisGitHubTeamCreationLimited'
            'Test-MtCisGitHubStrictBasePermission'
        )

        It 'Skips <_> when GitHub is not connected' -ForEach $functions {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = $null
            }

            & $_ | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $SkippedBecause -eq 'NotConnectedGitHub'
            }
            Should -Invoke Invoke-MtGitHubRequest -ModuleName Maester -Exactly -Times 0
        }
    }

    Context 'GitHub request errors' {
        $functions = @(
            'Test-MtCisGitHubRepositoryCreationLimited'
            'Test-MtCisGitHubRepositoryDeletionLimited'
            'Test-MtCisGitHubIssueDeletionLimited'
            'Test-MtCisGitHubTeamCreationLimited'
            'Test-MtCisGitHubStrictBasePermission'
        )

        It 'Skips <_> when the GitHub organization request throws' -ForEach $functions {
            Mock Invoke-MtGitHubRequest -ModuleName Maester { throw 'GitHub API boom' }

            & $_ | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $SkippedBecause -eq 'Error' -and $null -ne $SkippedError
            }
        }
    }
}
