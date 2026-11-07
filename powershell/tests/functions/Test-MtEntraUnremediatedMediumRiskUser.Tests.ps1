Describe 'Entra ID Protection unremediated medium-risk users (MT.1261)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtEntraUnremediatedMediumRiskUser
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedError = $null
        $script:Severity = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedError, $Severity)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedError = $SkippedError
            $script:Severity = $Severity
        }

        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() } -ParameterFilter {
            $RelativeUri -eq 'roleManagement/directory/roleDefinitions'
        }
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            return [pscustomobject]@{ Assignments = @(); EligibleChecked = $true }
        }
    }

    AfterEach {
        if ($null -ne $script:TestResult) {
            $script:TestResult | Should -Not -Match '`[^`]+`'
        }
    }

    It 'passes when there are no medium-risk users' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraUnremediatedMediumRiskUser | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
        # The medium-risk filter is what separates this check from MT.1260.
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $ApiVersion -eq 'v1.0' -and
            $RelativeUri -eq 'identityProtection/riskyUsers' -and
            $Filter -eq "riskLevel eq 'medium'"
        }
        Should -Invoke Get-MtDirectoryRoleAssignment -ModuleName Maester -Exactly -Times 0
    }

    It 'fails when a medium-risk user is atRisk' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id                      = 'user-1'
                    userPrincipalName       = 'alice@contoso.com'
                    userDisplayName         = 'Alice'
                    riskLevel               = 'medium'
                    riskState               = 'atRisk'
                    riskDetail              = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedMediumRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'alice@contoso.com'
        $script:TestResult | Should -Match 'atRisk'
    }

    It 'fails when a medium-risk user is confirmedCompromised (must not be treated as remediated)' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id                      = 'user-2'
                    userPrincipalName       = 'bob@contoso.com'
                    userDisplayName         = 'Bob'
                    riskLevel               = 'medium'
                    riskState               = 'confirmedCompromised'
                    riskDetail              = 'adminConfirmedUserCompromised'
                    riskLastUpdatedDateTime = '2026-10-02T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedMediumRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'bob@contoso.com'
        $script:TestResult | Should -Match 'confirmedCompromised'
    }

    It 'passes when the only medium-risk users are already remediated or dismissed' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'user-3'; userPrincipalName = 'carol@contoso.com'; userDisplayName = 'Carol'
                    riskLevel = 'medium'; riskState = 'remediated'; riskDetail = 'userPerformedSecuredPasswordReset'
                    riskLastUpdatedDateTime = '2026-10-03T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'user-4'; userPrincipalName = 'dave@contoso.com'; userDisplayName = 'Dave'
                    riskLevel = 'medium'; riskState = 'dismissed'; riskDetail = 'adminDismissedAllRiskForUser'
                    riskLastUpdatedDateTime = '2026-10-04T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedMediumRiskUser | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'reports only the unremediated users in a mixed set' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'user-1'; userPrincipalName = 'alice@contoso.com'; userDisplayName = 'Alice'
                    riskLevel = 'medium'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'user-3'; userPrincipalName = 'carol@contoso.com'; userDisplayName = 'Carol'
                    riskLevel = 'medium'; riskState = 'remediated'; riskDetail = 'userPerformedSecuredPasswordReset'
                    riskLastUpdatedDateTime = '2026-10-03T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedMediumRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'alice@contoso.com'
        $script:TestResult | Should -Not -Match 'carol@contoso.com'
        $script:TestResult | Should -Match 'Found 1 medium-risk'
    }

    It 'does not report a deleted user, whose risk an admin cannot dismiss' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'user-5'; isDeleted = $true; userPrincipalName = 'erin@contoso.com'; userDisplayName = 'Erin'
                    riskLevel = 'medium'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-05T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedMediumRiskUser | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'skips as NotAuthorized on a 403 from Graph' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden: Authorization_RequestDenied' }

        Test-MtEntraUnremediatedMediumRiskUser | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'lets an unexpected failure throw so the engine records it as Error' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Service unavailable' }

        { Test-MtEntraUnremediatedMediumRiskUser } | Should -Throw '*Service unavailable*'
    }

    Context 'Privileged users at risk' {
        BeforeEach {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(
                    [pscustomobject]@{ id = 'role-ga'; displayName = 'Global Administrator' },
                    [pscustomobject]@{ id = 'role-dr'; displayName = 'Directory Readers' }
                )
            } -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleDefinitions' }

            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @(
                    [pscustomobject]@{
                        id = 'user-1'; userPrincipalName = 'alice@contoso.com'; userDisplayName = 'Alice'
                        riskLevel = 'medium'; riskState = 'atRisk'; riskDetail = 'none'
                        riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                    },
                    [pscustomobject]@{
                        id = 'user-2'; userPrincipalName = 'bob@contoso.com'; userDisplayName = 'Bob'
                        riskLevel = 'medium'; riskState = 'atRisk'; riskDetail = 'none'
                        riskLastUpdatedDateTime = '2026-10-02T00:00:00Z'
                    }
                )
            } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyUsers' }

            Mock -ModuleName Maester Get-MtRoleInfo {
                return [pscustomobject]@{ IsPrivileged = ($RoleName -eq 'GlobalAdministrator') }
            }
        }

        It 'lists the role first when an at-risk user holds a privileged role' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'user-2'; roleDefinitionId = 'role-ga'; AssignmentType = 'Active' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedMediumRiskUser | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Match 'Global Administrator'
            $script:TestResult | Should -Match '1 of them hold a privileged directory role'
            $script:TestResult.IndexOf('bob@contoso.com') | Should -BeLessThan $script:TestResult.IndexOf('alice@contoso.com')
        }

        It 'treats a PIM-eligible privileged role as privileged' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'user-1'; roleDefinitionId = 'role-ga'; AssignmentType = 'Eligible' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedMediumRiskUser | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Match 'Global Administrator \(eligible\)'
        }

        It 'does not list a non-privileged role' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'user-1'; roleDefinitionId = 'role-dr'; AssignmentType = 'Active' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedMediumRiskUser | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Not -Match 'Directory Readers'
        }

        It 'notes when PIM-eligible assignments could not be read' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{ Assignments = @(); EligibleChecked = $false }
            }

            Test-MtEntraUnremediatedMediumRiskUser | Should -BeFalse
            $script:TestResult | Should -Match 'PIM-eligible role assignments were not checked'
        }

        It 'still reports the users when role assignments cannot be read' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment { throw 'Forbidden' }

            Test-MtEntraUnremediatedMediumRiskUser | Should -BeFalse
            $script:TestResult | Should -Match 'alice@contoso.com'
            $script:TestResult | Should -Match 'privileged users were not identified'
            $script:Severity | Should -BeNullOrEmpty
        }
    }
}
