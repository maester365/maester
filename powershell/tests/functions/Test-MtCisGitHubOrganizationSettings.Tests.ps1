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

        It 'Passes when GitHub returns mixed-case Read because -contains is case-insensitive' {
            # This documents PowerShell's default case-insensitive -contains behavior.
            $script:orgResponse.default_repository_permission = 'Read'

            Test-MtCisGitHubStrictBasePermission | Should -BeTrue
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
                Name     = 'repository creation when returned internal repository creation is allowed'
                Function = 'Test-MtCisGitHubRepositoryCreationLimited'
                Mutate   = { $script:orgResponse.members_can_create_internal_repositories = $true }
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
