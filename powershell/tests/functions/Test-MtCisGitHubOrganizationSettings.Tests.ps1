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
    }

    Context 'Pass cases' {
        It 'Passes the five core organization-setting controls when API evidence is compliant' {
            Test-MtCisGitHubRepositoryCreationLimited | Should -BeTrue
            Test-MtCisGitHubRepositoryDeletionLimited | Should -BeTrue
            Test-MtCisGitHubIssueDeletionLimited | Should -BeTrue
            Test-MtCisGitHubTeamCreationLimited | Should -BeTrue
            Test-MtCisGitHubStrictBasePermission | Should -BeTrue
        }

        It 'Passes repository creation when the internal repository field is not returned' {
            $script:orgResponse = [PSCustomObject]@{
                members_can_create_public_repositories  = $false
                members_can_create_private_repositories = $false
            }

            Test-MtCisGitHubRepositoryCreationLimited | Should -BeTrue
        }
    }

    Context 'Fail cases' {
        It 'Fails repository creation when public repository creation is allowed' {
            $script:orgResponse.members_can_create_public_repositories = $true

            Test-MtCisGitHubRepositoryCreationLimited | Should -BeFalse
        }

        It 'Fails strict base permissions when default permission is write' {
            $script:orgResponse.default_repository_permission = 'write'

            Test-MtCisGitHubStrictBasePermission | Should -BeFalse
        }
    }

    Context 'Missing evidence' {
        It 'Skips when a required field is missing' {
            $script:orgResponse = [PSCustomObject]@{ login = 'myorg' }

            Test-MtCisGitHubRepositoryDeletionLimited | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -match 'members_can_delete_repositories'
            }
        }
    }

    Context 'Disconnected GitHub' {
        It 'Skips when GitHub is not connected' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = $null
            }

            Test-MtCisGitHubTeamCreationLimited | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $SkippedBecause -eq 'NotConnectedGitHub'
            }
            Should -Invoke Invoke-MtGitHubRequest -ModuleName Maester -Exactly -Times 0
        }
    }
}
