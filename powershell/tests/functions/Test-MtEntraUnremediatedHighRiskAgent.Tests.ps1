Describe 'Entra ID Protection unremediated high-risk agents (MT.1284)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test function is not exported; reach it the same way the agent tests do.
        Use-MtModuleFunction -Name Test-MtEntraUnremediatedHighRiskAgent
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedError = $null
        $script:Severity = $null
        $script:GraphObjects = $null
        $script:GraphObjectType = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
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

    It 'passes when there are no high-risk agents' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
        # The high-risk filter is what separates this check from MT.1285, and agent risk is in beta only.
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $ApiVersion -eq 'beta' -and
            $RelativeUri -eq 'identityProtection/riskyAgents' -and
            $Filter -eq "riskLevel eq 'high'"
        }
        # A clean tenant makes no role lookups.
        Should -Invoke Get-MtDirectoryRoleAssignment -ModuleName Maester -Exactly -Times 0
    }

    It 'fails when a high-risk agent identity is atRisk' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-1'; agentDisplayName = 'Contoso Helper'; identityType = 'agentIdentity'; blueprintId = 'bp-1'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult | Should -Match 'Contoso Helper'
        $script:TestResult | Should -Match 'ag-1'
        $script:TestResult | Should -Match 'Agent identity'
        $script:TestResult | Should -Match 'atRisk'
        $script:TestResult | Should -Match '2026-10-01'
    }

    It 'fails when a high-risk agent is confirmedCompromised (must not be treated as remediated)' {
        # confirmCompromised lands an agent in confirmedCompromised, which is still unremediated.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-2'; agentDisplayName = 'Fabrikam Assistant'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'confirmedCompromised'
                    riskDetail = 'adminConfirmedAgentCompromised'; riskLastModifiedDateTime = '2026-10-02T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult | Should -Match 'Fabrikam Assistant'
        $script:TestResult | Should -Match 'confirmedCompromised'
    }

    It 'still reports a disabled high-risk agent (disabling does not close the risk)' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-9'; agentDisplayName = 'Disabled Agent'; identityType = 'agentIdentity'
                    isEnabled = $false; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult | Should -Match 'Disabled Agent \| Agent identity \| ag-9 \| No \|'
        @($script:GraphObjects.id) | Should -Be @('ag-9')
    }

    It 'does not report a deleted high-risk agent' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-8'; agentDisplayName = 'Deleted Agent'; identityType = 'agentIdentity'
                    isEnabled = $false; isDeleted = $true; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
        $script:GraphObjects | Should -BeNullOrEmpty
    }

    It 'passes when the only high-risk agents are already remediated, dismissed or confirmed safe' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-3'; agentDisplayName = 'Old Reporter'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'remediated'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-03T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'ag-4'; agentDisplayName = 'Legacy Bot'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'dismissed'; riskDetail = 'adminDismissedRiskForAgent'
                    riskLastModifiedDateTime = '2026-10-04T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'ag-6'; agentDisplayName = 'Checked Bot'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'confirmedSafe'; riskDetail = 'adminConfirmedAgentSafe'
                    riskLastModifiedDateTime = '2026-10-05T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'reports only the unremediated agents in a mixed set' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-1'; agentDisplayName = 'Contoso Helper'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'ag-3'; agentDisplayName = 'Old Reporter'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'remediated'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-03T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult | Should -Match 'Contoso Helper'
        $script:TestResult | Should -Not -Match 'Old Reporter'
        $script:TestResult | Should -Match 'Found 1 high-risk'
    }

    It 'names each agent type from @odata.type, falling back to identityType, and shows a type it does not know as Other agent' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    '@odata.type' = '#microsoft.graph.riskyAgentIdentity'
                    id = 'ag-1'; agentDisplayName = 'Alpha Agent'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    '@odata.type' = '#microsoft.graph.riskyAgentUser'
                    id = 'au-1'; agentDisplayName = 'Bravo Agent'; identityType = 'agentUser'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                },
                # Without the Prefer header Graph returns a blueprint principal's identityType as unknownFutureValue.
                [pscustomobject]@{
                    '@odata.type' = '#microsoft.graph.riskyAgentIdentityBlueprintPrincipal'
                    id = 'bp-1'; agentDisplayName = 'Charlie Agent'; identityType = 'unknownFutureValue'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                },
                # No @odata.type: identityType is used.
                [pscustomobject]@{
                    id = 'us-1'; agentDisplayName = 'Delta Agent'; identityType = 'user'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'xx-1'; agentDisplayName = 'Echo Agent'; identityType = 'unknownFutureValue'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult | Should -Match 'Alpha Agent \| Agent identity \|'
        $script:TestResult | Should -Match 'Bravo Agent \| Agent user \|'
        $script:TestResult | Should -Match 'Charlie Agent \| Blueprint principal \|'
        $script:TestResult | Should -Match 'Delta Agent \| User \|'
        $script:TestResult | Should -Match 'Echo Agent \| Other agent \|'
        # Every agent is in the table, but one of an unknown kind is not linked as an object of a guessed type.
        $script:TestResult | Should -Match 'Found 5 high-risk'
        @($script:GraphObjects.id) | Should -Be @('ag-1', 'au-1', 'bp-1', 'us-1')
        @($script:GraphObjects | ForEach-Object { $_.'@odata.type' }) | Should -Be @(
            '#microsoft.graph.servicePrincipal', '#microsoft.graph.user', '#microsoft.graph.servicePrincipal', '#microsoft.graph.user'
        )
    }

    It 'points to the portal when Graph withholds the risk detail, and shows Unknown for an unreadable date' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-2'; agentDisplayName = 'Fabrikam Assistant'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'confirmedCompromised'
                    riskDetail = 'unknownFutureValue'; riskLastModifiedDateTime = 'not a date'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult | Should -Match '\| confirmedCompromised \| Not returned by Graph, see the Risky agents report \| Unknown \|'
        $script:TestResult | Should -Not -Match 'unknownFutureValue'
    }

    It 'does not report risk states that are not active' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-3'; agentDisplayName = 'No State'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'none'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'ag-4'; agentDisplayName = 'Future State'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'unknownFutureValue'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'sorts agents without a privileged role by name' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-z'; agentDisplayName = 'Zulu Agent'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'ag-a'; agentDisplayName = 'Alpha Agent'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyAgents' }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult.IndexOf('Alpha Agent') | Should -BeLessThan $script:TestResult.IndexOf('Zulu Agent')
        @($script:GraphObjects.id) | Should -Be @('ag-a', 'ag-z')
    }

    It 'only reads from Graph (never changes an agent''s risk state)' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-1'; agentDisplayName = 'Contoso Helper'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyAgents' }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 2 -Exactly
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 0 -Exactly -ParameterFilter {
            $Method -and $Method -ne 'GET'
        }
    }

    It 'shows (unnamed) for an agent with no display name, and Unknown for a missing date or enabled flag' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-5'; agentDisplayName = ''; identityType = 'agentIdentity'
                    isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = $null
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult | Should -Match '\| \(unnamed\) \| Agent identity \| ag-5 \| Unknown \| atRisk \| none \| Unknown \|'
    }

    It 'escapes markdown in an agent name that comes from the tenant' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-7'; agentDisplayName = 'Evil | [Sign in](https://phish.example)'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:TestResult | Should -Not -Match '\[Sign in\]\(https://phish'
        $script:TestResult | Should -Match 'Evil \\\|'
    }

    It 'passes the unremediated agents to the report as affected objects with the right object type' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'ag-1'; agentDisplayName = 'Alpha Agent'; identityType = 'agentIdentity'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'au-1'; agentDisplayName = 'Bravo Agent'; identityType = 'agentUser'
                    isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'confirmedCompromised'; riskDetail = 'none'
                    riskLastModifiedDateTime = '2026-10-02T00:00:00Z'
                }
            )
        } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyAgents' }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
        $script:GraphObjectType | Should -BeNullOrEmpty
        @($script:GraphObjects).Count | Should -Be 2
        @($script:GraphObjects.id) | Should -Be @('ag-1', 'au-1')
        @($script:GraphObjects.displayName) | Should -Be @('Alpha Agent', 'Bravo Agent')
        # Agents' user accounts are users; agent identities are service principals.
        @($script:GraphObjects | ForEach-Object { $_.'@odata.type' }) | Should -Be @('#microsoft.graph.servicePrincipal', '#microsoft.graph.user')
    }

    It 'passes no affected objects when no agent is left unremediated' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyAgents' }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeTrue
        $script:GraphObjects | Should -BeNullOrEmpty
    }

    It 'skips as NotAuthorized on a 403 from Graph' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden: Authorization_RequestDenied' }

        Test-MtEntraUnremediatedHighRiskAgent | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'lets an unexpected failure throw so the engine records it as Error' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Service unavailable' }

        { Test-MtEntraUnremediatedHighRiskAgent } | Should -Throw '*Service unavailable*'
    }

    Context 'Privileged agents at risk' {
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
                        id = 'ag-1'; agentDisplayName = 'Contoso Helper'; identityType = 'agentIdentity'
                        isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                        riskLastModifiedDateTime = '2026-10-01T00:00:00Z'
                    },
                    [pscustomobject]@{
                        id = 'ag-2'; agentDisplayName = 'Fabrikam Assistant'; identityType = 'agentIdentity'
                        isEnabled = $true; isDeleted = $false; riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                        riskLastModifiedDateTime = '2026-10-02T00:00:00Z'
                    }
                )
            } -ParameterFilter { $RelativeUri -eq 'identityProtection/riskyAgents' }

            Mock -ModuleName Maester Get-MtRoleInfo {
                return [pscustomobject]@{ IsPrivileged = ($RoleName -eq 'GlobalAdministrator') }
            }
        }

        It 'lists the role first when an at-risk agent holds a privileged role' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'ag-2'; roleDefinitionId = 'role-ga'; AssignmentType = 'Active' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Match 'Global Administrator'
            $script:TestResult | Should -Match '1 of them hold a privileged directory role'
            # The privileged agent is listed first.
            $script:TestResult.IndexOf('Fabrikam Assistant') | Should -BeLessThan $script:TestResult.IndexOf('Contoso Helper')
        }

        It 'treats a PIM-eligible privileged role as privileged' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'ag-1'; roleDefinitionId = 'role-ga'; AssignmentType = 'Eligible' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Match 'Global Administrator \\\(eligible\\\)'
        }

        It 'does not list a non-privileged role' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{
                    Assignments     = @([pscustomobject]@{ principalId = 'ag-1'; roleDefinitionId = 'role-dr'; AssignmentType = 'Active' })
                    EligibleChecked = $true
                }
            }

            Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
            $script:Severity | Should -BeNullOrEmpty
            $script:TestResult | Should -Not -Match 'Directory Readers'
        }

        It 'notes when PIM-eligible assignments could not be read' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment {
                return [pscustomobject]@{ Assignments = @(); EligibleChecked = $false }
            }

            Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
            $script:TestResult | Should -Match 'PIM-eligible role assignments were not checked'
        }

        It 'still reports the agents when role assignments cannot be read' {
            Mock -ModuleName Maester Get-MtDirectoryRoleAssignment { throw 'Forbidden' }

            Test-MtEntraUnremediatedHighRiskAgent | Should -BeFalse
            $script:TestResult | Should -Match 'Contoso Helper'
            $script:TestResult | Should -Match 'privileged agents were not identified'
            $script:Severity | Should -BeNullOrEmpty
        }
    }
}
