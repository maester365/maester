Describe 'MT.1223: Test-MtEntraAgentHighRiskGraphPermissions' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedError = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedError)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedError = $SkippedError
        }
    }

    It 'passes when no Agent Identities exist' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'fails when an Agent Identity has a risky application permission' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch -Wildcard ($RelativeUri) {
                'servicePrincipals/microsoft.graph.agentIdentity' {
                    return @([pscustomobject]@{
                            id          = 'agent-1'
                            displayName = 'Application agent'
                            appId       = 'app-1'
                        })
                }
                'servicePrincipals' {
                    return @([pscustomobject]@{
                            id       = 'graph-sp'
                            appRoles = @([pscustomobject]@{
                                    id    = 'risky-role-id'
                                    value = 'RoleAssignmentSchedule.ReadWrite.Directory'
                                })
                        })
                }
                'servicePrincipals/agent-1/appRoleAssignments' {
                    return @([pscustomobject]@{
                            appRoleId  = 'risky-role-id'
                            resourceId = 'graph-sp'
                        })
                }
                'servicePrincipals/agent-1/oauth2PermissionGrants' { return @() }
                '*agent-1/inheritedAppRoleAssignments' { return @() }
                '*agent-1/inheritedOauth2PermissionGrants' { return @() }
                default { throw "Unexpected Graph request: $RelativeUri" }
            }
        }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeFalse
        $script:TestResult | Should -Match 'RoleAssignmentSchedule.ReadWrite.Directory'
        $script:TestResult | Should -Match 'Application'
        $script:TestResult | Should -Match '\| agent-1 \| Application agent \| app-1 \|'
        $script:TestResult | Should -Not -Match '`agent-1`'
    }

    It 'fails when an Agent Identity has a risky delegated permission' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch -Wildcard ($RelativeUri) {
                'servicePrincipals/microsoft.graph.agentIdentity' {
                    return @([pscustomobject]@{
                            id          = 'agent-2'
                            displayName = 'Delegated agent'
                            appId       = 'app-2'
                        })
                }
                'servicePrincipals' {
                    return @([pscustomobject]@{ id = 'graph-sp'; appRoles = @() })
                }
                'servicePrincipals/agent-2/appRoleAssignments' { return @() }
                'servicePrincipals/agent-2/oauth2PermissionGrants' {
                    return @([pscustomobject]@{
                            resourceId = 'graph-sp'
                            scope      = 'User.Read RoleEligibilitySchedule.ReadWrite.Directory'
                        })
                }
                '*agent-2/inheritedAppRoleAssignments' { return @() }
                '*agent-2/inheritedOauth2PermissionGrants' { return @() }
                default { throw "Unexpected Graph request: $RelativeUri" }
            }
        }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeFalse
        $script:TestResult | Should -Match 'RoleEligibilitySchedule.ReadWrite.Directory'
        $script:TestResult | Should -Match 'Delegated'
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 2 -Exactly `
            -ParameterFilter {
                $RelativeUri -like '*inherited*' -and
                !$PSBoundParameters.ContainsKey('Select')
            }
    }

    It 'passes when Agent Identities have only non-risky Graph permissions' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch -Wildcard ($RelativeUri) {
                'servicePrincipals/microsoft.graph.agentIdentity' {
                    return @([pscustomobject]@{
                            id          = 'agent-3'
                            displayName = 'Low-risk agent'
                            appId       = 'app-3'
                        })
                }
                'servicePrincipals' {
                    return @([pscustomobject]@{
                            id       = 'graph-sp'
                            appRoles = @([pscustomobject]@{
                                    id = 'user-read-id'; value = 'User.Read.All'
                                })
                        })
                }
                'servicePrincipals/agent-3/appRoleAssignments' {
                    return @([pscustomobject]@{
                            appRoleId  = 'user-read-id'
                            resourceId = 'graph-sp'
                        })
                }
                'servicePrincipals/agent-3/oauth2PermissionGrants' {
                    return @([pscustomobject]@{ resourceId = 'graph-sp'; scope = 'User.Read' })
                }
                '*agent-3/inheritedAppRoleAssignments' { return @() }
                '*agent-3/inheritedOauth2PermissionGrants' { return @() }
                default { throw "Unexpected Graph request: $RelativeUri" }
            }
        }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'ignores high-risk permission names granted for resources other than Microsoft Graph' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch -Wildcard ($RelativeUri) {
                'servicePrincipals/microsoft.graph.agentIdentity' {
                    return @([pscustomobject]@{
                            id          = 'agent-4'
                            displayName = 'Other resource agent'
                            appId       = 'app-4'
                        })
                }
                'servicePrincipals' {
                    return @([pscustomobject]@{
                            id       = 'graph-sp'
                            appRoles = @([pscustomobject]@{
                                    id    = 'risky-role-id'
                                    value = 'RoleAssignmentSchedule.ReadWrite.Directory'
                                })
                        })
                }
                'servicePrincipals/agent-4/appRoleAssignments' {
                    return @([pscustomobject]@{
                            appRoleId  = 'risky-role-id'
                            resourceId = 'other-resource-sp'
                        })
                }
                'servicePrincipals/agent-4/oauth2PermissionGrants' {
                    return @([pscustomobject]@{
                            resourceId = 'other-resource-sp'
                            scope      = 'RoleEligibilitySchedule.ReadWrite.Directory'
                        })
                }
                '*agent-4/inheritedAppRoleAssignments' { return @() }
                '*agent-4/inheritedOauth2PermissionGrants' { return @() }
                default { throw "Unexpected Graph request: $RelativeUri" }
            }
        }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'fails when an Agent Identity inherits a risky application permission' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch -Wildcard ($RelativeUri) {
                'servicePrincipals/microsoft.graph.agentIdentity' {
                    return @([pscustomobject]@{
                            id = 'agent-5'; displayName = 'Inherited app agent'; appId = 'app-5'
                        })
                }
                'servicePrincipals' {
                    return @([pscustomobject]@{
                            id = 'graph-sp'
                            appRoles = @([pscustomobject]@{
                                    id = 'risky-role-id'
                                    value = 'RoleAssignmentSchedule.ReadWrite.Directory'
                                })
                        })
                }
                'servicePrincipals/agent-5/appRoleAssignments' { return @() }
                'servicePrincipals/agent-5/oauth2PermissionGrants' { return @() }
                '*agent-5/inheritedAppRoleAssignments' {
                    return @([pscustomobject]@{
                            appRoleId = 'risky-role-id'; resourceId = 'graph-sp'
                        })
                }
                '*agent-5/inheritedOauth2PermissionGrants' { return @() }
                default { throw "Unexpected Graph request: $RelativeUri" }
            }
        }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeFalse
        $script:TestResult | Should -Match 'RoleAssignmentSchedule.ReadWrite.Directory'
        $script:TestResult | Should -Match 'Application'
    }

    It 'fails when an Agent Identity inherits a risky delegated permission' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch -Wildcard ($RelativeUri) {
                'servicePrincipals/microsoft.graph.agentIdentity' {
                    return @([pscustomobject]@{
                            id = 'agent-6'
                            displayName = 'Inherited delegated agent'
                            appId = 'app-6'
                        })
                }
                'servicePrincipals' {
                    return @([pscustomobject]@{ id = 'graph-sp'; appRoles = @() })
                }
                'servicePrincipals/agent-6/appRoleAssignments' { return @() }
                'servicePrincipals/agent-6/oauth2PermissionGrants' { return @() }
                '*agent-6/inheritedAppRoleAssignments' { return @() }
                '*agent-6/inheritedOauth2PermissionGrants' {
                    return @([pscustomobject]@{
                            resourceId = 'graph-sp'
                            scope = 'RoleEligibilitySchedule.ReadWrite.Directory'
                        })
                }
                default { throw "Unexpected Graph request: $RelativeUri" }
            }
        }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeFalse
        $script:TestResult | Should -Match 'RoleEligibilitySchedule.ReadWrite.Directory'
        $script:TestResult | Should -Match 'Delegated'
    }

    It 'skips when Graph is disconnected' {
        Mock -ModuleName Maester Test-MtConnection { return $false }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotConnectedGraph'
    }

    It 'skips when Graph returns an error' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph unavailable' }

        Test-MtEntraAgentHighRiskGraphPermissions | Should -BeNull
        $script:SkippedBecause | Should -Be 'Error'
        $script:SkippedError.Exception.Message | Should -Be 'Graph unavailable'
    }
}
