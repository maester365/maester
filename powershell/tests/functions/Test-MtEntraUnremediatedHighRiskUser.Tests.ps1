Describe 'Entra ID Protection unremediated high-risk users (MT.1260)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test function is not exported; reach it the same way the agent tests do.
        Use-MtModuleFunction -Name Test-MtEntraUnremediatedHighRiskUser
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

        # Role lookups default to "no roles". Tests that need roles override these.
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() } -ParameterFilter {
            $RelativeUri -eq 'roleManagement/directory/roleDefinitions'
        }
        Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
            return [pscustomobject]@{ Assignments = @(); EligibleChecked = $true }
        }
    }

    AfterEach {
        # Result text must not contain backtick-wrapped code spans (repo result-text lint).
        if ($null -ne $script:TestResult) {
            $script:TestResult | Should -Not -Match '`[^`]+`'
        }
    }

    It 'passes when there are no high-risk users' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
        # The high-risk filter is what separates this check from MT.1261.
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $ApiVersion -eq 'v1.0' -and
            $RelativeUri -eq 'identityProtection/riskyUsers' -and
            $Filter -eq "riskLevel eq 'high'"
        }
        # A clean tenant makes no role lookups.
        Should -Invoke Get-MtDirectoryRoleAssignment -ModuleName Maester -Exactly -Times 0
    }

    It 'fails when a high-risk user is atRisk' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id                      = 'user-1'
                    userPrincipalName       = 'alice@contoso.com'
                    userDisplayName         = 'Alice'
                    riskLevel               = 'high'
                    riskState               = 'atRisk'
                    riskDetail              = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'alice@contoso.com'
        $script:TestResult | Should -Match 'atRisk'
    }

    It 'fails when a high-risk user is confirmedCompromised (must not be treated as remediated)' {
        # This is the case that breaks if the check filters on riskState eq atRisk only:
        # confirmCompromised lands a user in confirmedCompromised, which is still unremediated.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id                      = 'user-2'
                    userPrincipalName       = 'bob@contoso.com'
                    userDisplayName         = 'Bob'
                    riskLevel               = 'high'
                    riskState               = 'confirmedCompromised'
                    riskDetail              = 'adminConfirmedUserCompromised'
                    riskLastUpdatedDateTime = '2026-10-02T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'bob@contoso.com'
        $script:TestResult | Should -Match 'confirmedCompromised'
    }

    It 'passes when the only high-risk users are already remediated or dismissed' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'user-3'; userPrincipalName = 'carol@contoso.com'; userDisplayName = 'Carol'
                    riskLevel = 'high'; riskState = 'remediated'; riskDetail = 'userPerformedSecuredPasswordReset'
                    riskLastUpdatedDateTime = '2026-10-03T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'user-4'; userPrincipalName = 'dave@contoso.com'; userDisplayName = 'Dave'
                    riskLevel = 'high'; riskState = 'dismissed'; riskDetail = 'adminDismissedAllRiskForUser'
                    riskLastUpdatedDateTime = '2026-10-04T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'reports only the unremediated users in a mixed set' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'user-1'; userPrincipalName = 'alice@contoso.com'; userDisplayName = 'Alice'
                    riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'user-3'; userPrincipalName = 'carol@contoso.com'; userDisplayName = 'Carol'
                    riskLevel = 'high'; riskState = 'remediated'; riskDetail = 'userPerformedSecuredPasswordReset'
                    riskLastUpdatedDateTime = '2026-10-03T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'alice@contoso.com'
        $script:TestResult | Should -Not -Match 'carol@contoso.com'
        $script:TestResult | Should -Match 'Found 1 high-risk'
    }

    It 'skips as NotAuthorized on a 403 from Graph' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden: Authorization_RequestDenied' }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'lets an unexpected failure throw so the engine records it as Error' {
        # The engine owns the try: a non-403 failure must propagate, not be swallowed by the check.
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Service unavailable' }

        { Test-MtEntraUnremediatedHighRiskUser } | Should -Throw '*Service unavailable*'
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
                        riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                        riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                    },
                    [pscustomobject]@{
                        id = 'user-2'; userPrincipalName = 'bob@contoso.com'; userDisplayName = 'Bob'
                        riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                        riskLastUpdatedDateTime = '2026-10-02T00:00:00Z'
                    }
                )
            } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyUsers' }

            Mock -ModuleName Maester Get-MtRoleInfo {
                return [pscustomobject]@{ IsPrivileged = ($RoleName -eq 'GlobalAdministrator') }
            }
        }

        It 'raises severity to High and lists the role when an at-risk user holds a privileged role' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'user-2'; roleDefinitionId = 'role-ga'; AssignmentType = 'Active' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
            $script:Severity | Should -Be 'High'
            $script:TestResult | Should -Match 'Global Administrator'
            $script:TestResult | Should -Match '1 of them hold a privileged directory role'
            # The privileged user is listed first.
            $script:TestResult.IndexOf('bob@contoso.com') | Should -BeLessThan $script:TestResult.IndexOf('alice@contoso.com')
        }

        It 'treats a PIM-eligible privileged role as privileged' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'user-1'; roleDefinitionId = 'role-ga'; AssignmentType = 'Eligible' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
            $script:Severity | Should -Be 'High'
            $script:TestResult | Should -Match 'Global Administrator \(eligible\)'
        }

        It 'does not raise severity for a non-privileged role' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'user-1'; roleDefinitionId = 'role-dr'; AssignmentType = 'Active' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Not -Match 'Directory Readers'
        }

        It 'notes when PIM-eligible assignments could not be read' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{ Assignments = @(); EligibleChecked = $false }
            }

            Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
            $script:TestResult | Should -Match 'PIM-eligible role assignments were not checked'
        }

        It 'still reports the users when role assignments cannot be read' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment { throw 'Forbidden' }

            Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
            $script:TestResult | Should -Match 'alice@contoso.com'
            $script:TestResult | Should -Match 'privileged users were not identified'
            $script:Severity | Should -BeNullOrEmpty
        }
    }
}
