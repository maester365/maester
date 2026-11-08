Describe 'Entra ID Protection unremediated high-risk service principals (MT.1262)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test function is not exported; reach it the same way the agent tests do.
        Use-MtModuleFunction -Name Test-MtEntraUnremediatedHighRiskServicePrincipal
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedError = $null
        $script:Severity = $null
        $script:GraphObjects = $null
        $script:GraphObjectType = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Get-MtLinkServicePrincipal { return "[$($ServicePrincipal.DisplayName)](link)" }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedError, $Severity, $GraphObjects, $GraphObjectType)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedError = $SkippedError
            $script:Severity = $Severity
            $script:GraphObjects = $GraphObjects
            $script:GraphObjectType = $GraphObjectType
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

    It 'passes when there are no high-risk service principals' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
        # The high-risk filter is what separates this check from MT.1263.
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $ApiVersion -eq 'v1.0' -and
            $RelativeUri -eq 'identityProtection/riskyServicePrincipals' -and
            $Filter -eq "riskLevel eq 'high'"
        }
        # A clean tenant makes no role lookups.
        Should -Invoke Get-MtDirectoryRoleAssignment -ModuleName Maester -Exactly -Times 0
    }

    It 'fails when a high-risk service principal is atRisk' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'sp-1'; appId = 'app-1'; displayName = 'Contoso Sync'; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
        $script:TestResult | Should -Match 'Contoso Sync'
        $script:TestResult | Should -Match 'app-1'
        $script:TestResult | Should -Match 'atRisk'
    }

    It 'fails when a high-risk service principal is confirmedCompromised (must not be treated as remediated)' {
        # confirmCompromised lands a service principal in confirmedCompromised, which is still unremediated.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'sp-2'; appId = 'app-2'; displayName = 'Fabrikam Backup'; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'confirmedCompromised'; riskDetail = 'adminConfirmedServicePrincipalCompromised'
                    riskLastUpdatedDateTime = '2026-10-02T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
        $script:TestResult | Should -Match 'Fabrikam Backup'
        $script:TestResult | Should -Match 'confirmedCompromised'
    }

    It 'passes when the only high-risk service principals are already remediated or dismissed' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'sp-3'; appId = 'app-3'; displayName = 'Old Reporting'; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'remediated'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-03T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'sp-4'; appId = 'app-4'; displayName = 'Legacy Connector'; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'dismissed'; riskDetail = 'adminDismissedAllRiskForServicePrincipal'
                    riskLastUpdatedDateTime = '2026-10-04T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'reports only the unremediated service principals in a mixed set' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'sp-1'; appId = 'app-1'; displayName = 'Contoso Sync'; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'sp-3'; appId = 'app-3'; displayName = 'Old Reporting'; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'remediated'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-03T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
        $script:TestResult | Should -Match 'Contoso Sync'
        $script:TestResult | Should -Not -Match 'Old Reporting'
        $script:TestResult | Should -Match 'Found 1 high-risk'
    }

    It 'shows (unnamed) for a service principal with no display name' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'sp-5'; appId = 'app-5'; displayName = ''; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastUpdatedDateTime = $null
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
        $script:TestResult | Should -Match '\(unnamed\)'
        $script:TestResult | Should -Match 'Unknown'
    }

    It 'passes the unremediated service principals to the report as affected objects' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'sp-1'; appId = 'app-1'; displayName = 'Alpha App'; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'sp-2'; appId = 'app-2'; displayName = 'Bravo App'; servicePrincipalType = 'Application'
                    riskLevel = 'high'; riskState = 'confirmedCompromised'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-02T00:00:00Z'
                }
            )
        } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyServicePrincipals' }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
        $script:GraphObjectType | Should -BeNullOrEmpty
        @($script:GraphObjects).Count | Should -Be 2
        @($script:GraphObjects.id) | Should -Be @('sp-1', 'sp-2')
        @($script:GraphObjects.displayName) | Should -Be @('Alpha App', 'Bravo App')
        @($script:GraphObjects | ForEach-Object { $_.'@odata.type' }) | Should -Be @('#microsoft.graph.servicePrincipal', '#microsoft.graph.servicePrincipal')
    }

    It 'passes no affected objects when no service principal is left unremediated' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyServicePrincipals' }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeTrue
        $script:GraphObjects | Should -BeNullOrEmpty
    }

    It 'skips as NotAuthorized on a 403 from Graph' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden: Authorization_RequestDenied' }

        Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'lets an unexpected failure throw so the engine records it as Error' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Service unavailable' }

        { Test-MtEntraUnremediatedHighRiskServicePrincipal } | Should -Throw '*Service unavailable*'
    }

    Context 'Privileged service principals at risk' {
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
                        id = 'sp-1'; appId = 'app-1'; displayName = 'Contoso Sync'; servicePrincipalType = 'Application'
                        riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                        riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                    },
                    [pscustomobject]@{
                        id = 'sp-2'; appId = 'app-2'; displayName = 'Fabrikam Backup'; servicePrincipalType = 'Application'
                        riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                        riskLastUpdatedDateTime = '2026-10-02T00:00:00Z'
                    }
                )
            } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyServicePrincipals' }

            Mock -ModuleName Maester Get-MtRoleInfo {
                return [pscustomobject]@{ IsPrivileged = ($RoleName -eq 'GlobalAdministrator') }
            }
        }

        It 'lists the role first when an at-risk service principal holds a privileged role' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'sp-2'; roleDefinitionId = 'role-ga'; AssignmentType = 'Active' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Match 'Global Administrator'
            $script:TestResult | Should -Match '1 of them hold a privileged directory role'
            # The privileged service principal is listed first.
            $script:TestResult.IndexOf('Fabrikam Backup') | Should -BeLessThan $script:TestResult.IndexOf('Contoso Sync')
        }

        It 'treats a PIM-eligible privileged role as privileged' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'sp-1'; roleDefinitionId = 'role-ga'; AssignmentType = 'Eligible' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Match 'Global Administrator \\\(eligible\\\)'
        }

        It 'does not list a non-privileged role' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'sp-1'; roleDefinitionId = 'role-dr'; AssignmentType = 'Active' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Not -Match 'Directory Readers'
        }

        It 'notes when PIM-eligible assignments could not be read' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{ Assignments = @(); EligibleChecked = $false }
            }

            Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
            $script:TestResult | Should -Match 'PIM-eligible role assignments were not checked'
        }

        It 'still reports the service principals when role assignments cannot be read' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment { throw 'Forbidden' }

            Test-MtEntraUnremediatedHighRiskServicePrincipal | Should -BeFalse
            $script:TestResult | Should -Match 'Contoso Sync'
            $script:TestResult | Should -Match 'privileged service principals were not identified'
            $script:Severity | Should -BeNullOrEmpty
        }
    }
}
