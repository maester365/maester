Describe 'Entra Agent ID security checks (MT.3001 - MT.3007)' {
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

    Context 'MT.3001: Test-MtEntraAgentOwner' {
        It 'passes when every object has an active owner' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                switch -Wildcard ($RelativeUri) {
                    '*agentIdentityBlueprintPrincipal' {
                        return @([pscustomobject]@{ id = 'principal-1'; displayName = 'Principal 1' })
                    }
                    'applications/*' {
                        if ($RelativeUri -like '*/owners') {
                            return @([pscustomobject]@{ id = 'user-1'; accountEnabled = $true })
                        }
                        return @([pscustomobject]@{ id = 'blueprint-1'; displayName = 'Blueprint 1'; appId = 'app-1' })
                    }
                    'servicePrincipals/*' {
                        if ($RelativeUri -like '*/owners') {
                            return @([pscustomobject]@{ id = 'user-1'; accountEnabled = $true })
                        }
                        return @([pscustomobject]@{ id = 'identity-1'; displayName = 'Identity 1' })
                    }
                    default { return @() }
                }
            }

            Test-MtEntraAgentOwner | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'reports an object when it has no owners' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                switch -Wildcard ($RelativeUri) {
                    '*agentIdentityBlueprintPrincipal' { return @() }
                    'applications/*' { return @() }
                    'servicePrincipals/*' {
                        if ($RelativeUri -like '*/owners') { return @() }
                        return @([pscustomobject]@{ id = 'identity-1'; displayName = 'Identity 1' })
                    }
                    default { return @() }
                }
            }

            Test-MtEntraAgentOwner | Should -BeFalse
            $script:TestResult | Should -Match 'identity-1'
            $script:TestResult | Should -Match 'No owners are assigned'
        }

        It 'reports an object when all assigned owners are disabled' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                switch -Wildcard ($RelativeUri) {
                    '*agentIdentityBlueprintPrincipal' { return @() }
                    'applications/*' { return @() }
                    'servicePrincipals/*' {
                        if ($RelativeUri -like '*/owners') {
                            return @([pscustomobject]@{ id = 'user-disabled'; accountEnabled = $false })
                        }
                        return @([pscustomobject]@{ id = 'identity-1'; displayName = 'Identity 1' })
                    }
                    default { return @() }
                }
            }

            Test-MtEntraAgentOwner | Should -BeFalse
            $script:TestResult | Should -Match 'disabled accounts'
        }

        It 'skips when Graph is disconnected' {
            Mock -ModuleName Maester Test-MtConnection { return $false }
            Test-MtEntraAgentOwner | Should -BeNull
            $script:SkippedBecause | Should -Be 'NotConnectedGraph'
        }
    }

    Context 'MT.3002: Test-MtEntraAgentSponsor' {
        It 'passes when every blueprint has assigned sponsors' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                switch -Wildcard ($RelativeUri) {
                    '*/sponsors' {
                        return @([pscustomobject]@{ id = 'sponsor-1'; accountEnabled = $true })
                    }
                    '*agentIdentityBlueprintPrincipal' {
                        return @([pscustomobject]@{ id = 'principal-1'; displayName = 'Principal 1'; appId = 'app-1' })
                    }
                    'applications/*' {
                        return @([pscustomobject]@{ id = 'blueprint-1'; displayName = 'Blueprint 1'; appId = 'app-1' })
                    }
                    default { return @() }
                }
            }

            Test-MtEntraAgentSponsor | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'reports a blueprint principal without sponsors' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                switch -Wildcard ($RelativeUri) {
                    '*/sponsors' { return @() }
                    '*agentIdentityBlueprintPrincipal' {
                        return @([pscustomobject]@{ id = 'principal-1'; displayName = 'Principal 1'; appId = 'app-1' })
                    }
                    'applications/*' { return @() }
                    default { return @() }
                }
            }

            Test-MtEntraAgentSponsor | Should -BeFalse
            $script:TestResult | Should -Match 'principal-1'
            $script:TestResult | Should -Match 'No sponsors are assigned'
        }
    }

    Context 'MT.3003: Test-MtEntraAgentInactive' {
        It 'passes when enabled agents have recent sign-in activity' {
            $RecentDate = (Get-Date).AddDays(-10).ToString('o')
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like 'reports/*') {
                    return @([pscustomobject]@{ appId = 'app-1'; lastSignInDateTime = $RecentDate })
                }
                return @([pscustomobject]@{ id = 'id-1'; appId = 'app-1'; displayName = 'Agent 1'; accountEnabled = $true })
            }

            Test-MtEntraAgentInactive | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'reports an enabled agent with stale sign-in activity' {
            $StaleDate = (Get-Date).AddDays(-200).ToString('o')
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like 'reports/*') {
                    return @([pscustomobject]@{ appId = 'app-1'; lastSignInDateTime = $StaleDate })
                }
                return @([pscustomobject]@{ id = 'id-1'; appId = 'app-1'; displayName = 'Agent 1'; accountEnabled = $true })
            }

            Test-MtEntraAgentInactive | Should -BeFalse
            $script:TestResult | Should -Match 'id-1'
            $script:TestResult | Should -Match 'Inactive for'
        }
    }

    Context 'MT.3004: Test-MtEntraAgentForeignPrivileged' {
        It 'passes when no foreign blueprints exist' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -eq 'organization') {
                    return @([pscustomobject]@{ id = 'local-tenant-123' })
                }
                if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') {
                    return @([pscustomobject]@{
                        id = 'principal-1'; displayName = 'Principal 1'; appId = 'app-1'; appOwnerOrganizationId = 'local-tenant-123'
                    })
                }
                return @()
            }

            Test-MtEntraAgentForeignPrivileged | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'reports a foreign blueprint principal with assigned directory role' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -eq 'organization') {
                    return @([pscustomobject]@{ id = 'local-tenant-123' })
                }
                if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') {
                    return @([pscustomobject]@{
                        id = 'foreign-principal-1'; displayName = 'Foreign Principal'; appId = 'foreign-app-1'; appOwnerOrganizationId = 'foreign-tenant-999'
                    })
                }
                if ($RelativeUri -like '*roleDefinitions') {
                    return @([pscustomobject]@{ id = 'role-ga'; displayName = 'Global Administrator'; isPrivileged = $true })
                }
                if ($RelativeUri -like '*roleAssignments') {
                    return @([pscustomobject]@{ principalId = 'foreign-principal-1'; roleDefinitionId = 'role-ga' })
                }
                return @()
            }

            Test-MtEntraAgentForeignPrivileged | Should -BeFalse
            $script:TestResult | Should -Match 'foreign-principal-1'
            $script:TestResult | Should -Match 'Global Administrator'
        }

        It 'passes when a foreign blueprint principal has a non-privileged directory role' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -eq 'organization') {
                    return @([pscustomobject]@{ id = 'local-tenant-123' })
                }
                if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') {
                    return @([pscustomobject]@{
                        id = 'foreign-principal-1'; displayName = 'Foreign Principal'; appId = 'foreign-app-1'; appOwnerOrganizationId = 'foreign-tenant-999'
                    })
                }
                if ($RelativeUri -like '*roleDefinitions') {
                    return @([pscustomobject]@{ id = 'role-reader'; displayName = 'Reports Reader'; isPrivileged = $false })
                }
                if ($RelativeUri -like '*roleAssignments') {
                    return @([pscustomobject]@{ principalId = 'foreign-principal-1'; roleDefinitionId = 'role-reader' })
                }
                return @()
            }

            Test-MtEntraAgentForeignPrivileged | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'passes but reports application permissions on a foreign blueprint principal as an observation' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -eq 'organization') {
                    return @([pscustomobject]@{ id = 'local-tenant-123' })
                }
                if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') {
                    return @([pscustomobject]@{
                        id = 'foreign-principal-1'; displayName = 'Foreign Principal'; appId = 'foreign-app-1'; appOwnerOrganizationId = 'foreign-tenant-999'
                    })
                }
                if ($RelativeUri -like '*appRoleAssignments') {
                    return @([pscustomobject]@{ id = 'assignment-1'; resourceDisplayName = 'Microsoft Graph'; appRoleId = 'role-id-1' })
                }
                return @()
            }

            Test-MtEntraAgentForeignPrivileged | Should -BeTrue
            $script:TestResult | Should -Match 'foreign-principal-1'
            $script:TestResult | Should -Match 'observation'
        }
    }

    Context 'MT.3005: Test-MtEntraAgentBlueprintCredentialHygiene' {
        It 'passes when blueprints have healthy credentials' {
            $ValidEnd = (Get-Date).AddDays(180).ToString('o')
            $ValidStart = (Get-Date).AddDays(-10).ToString('o')
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @([pscustomobject]@{
                    id = 'bp-1'; displayName = 'BP 1'; appId = 'app-1'
                    passwordCredentials = @([pscustomobject]@{ keyId = 'key-1'; startDateTime = $ValidStart; endDateTime = $ValidEnd })
                })
            }

            Test-MtEntraAgentBlueprintCredentialHygiene | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'reports a blueprint with an expired client secret' {
            $ExpiredEnd = (Get-Date).AddDays(-10).ToString('o')
            $ValidStart = (Get-Date).AddDays(-365).ToString('o')
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @([pscustomobject]@{
                    id = 'bp-1'; displayName = 'BP 1'; appId = 'app-1'
                    passwordCredentials = @([pscustomobject]@{ keyId = 'expired-key'; startDateTime = $ValidStart; endDateTime = $ExpiredEnd })
                })
            }

            Test-MtEntraAgentBlueprintCredentialHygiene | Should -BeFalse
            $script:TestResult | Should -Match 'Expired secret'
        }

        It 'reports a blueprint with excessive active secrets' {
            $ValidEnd = (Get-Date).AddDays(180).ToString('o')
            $ValidStart = (Get-Date).AddDays(-10).ToString('o')
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                return @([pscustomobject]@{
                    id = 'bp-1'; displayName = 'BP 1'; appId = 'app-1'
                    passwordCredentials = @(
                        [pscustomobject]@{ keyId = 'key-1'; startDateTime = $ValidStart; endDateTime = $ValidEnd },
                        [pscustomobject]@{ keyId = 'key-2'; startDateTime = $ValidStart; endDateTime = $ValidEnd },
                        [pscustomobject]@{ keyId = 'key-3'; startDateTime = $ValidStart; endDateTime = $ValidEnd }
                    )
                })
            }

            Test-MtEntraAgentBlueprintCredentialHygiene | Should -BeFalse
            $script:TestResult | Should -Match 'Excessive active secrets'
        }
    }

    Context 'MT.3006: Test-MtEntraAgentDirectoryRoles' {
        It 'passes when no Agent ID has directory roles' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like '*roleAssignments') { return @() }
                if ($RelativeUri -like '*agentIdentity') {
                    return @([pscustomobject]@{ id = 'agent-1'; displayName = 'Agent 1'; appId = 'app-1' })
                }
                return @()
            }

            Test-MtEntraAgentDirectoryRoles | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'reports an Agent Identity with assigned directory role' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like 'servicePrincipals/microsoft.graph.agentIdentity') {
                    return @([pscustomobject]@{ id = 'agent-1'; displayName = 'Agent 1'; appId = 'app-1' })
                }
                if ($RelativeUri -like '*roleDefinitions') {
                    return @([pscustomobject]@{ id = 'role-appadmin'; displayName = 'Application Administrator'; isPrivileged = $true })
                }
                if ($RelativeUri -like '*roleAssignments') {
                    return @([pscustomobject]@{ principalId = 'agent-1'; roleDefinitionId = 'role-appadmin'; directoryScopeId = '/' })
                }
                return @()
            }

            Test-MtEntraAgentDirectoryRoles | Should -BeFalse
            $script:TestResult | Should -Match 'agent-1'
            $script:TestResult | Should -Match 'Application Administrator'
        }

        It 'passes when the only assigned role is not privileged' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like 'servicePrincipals/microsoft.graph.agentIdentity') {
                    return @([pscustomobject]@{ id = 'agent-1'; displayName = 'Agent 1'; appId = 'app-1' })
                }
                if ($RelativeUri -like '*roleDefinitions') {
                    return @([pscustomobject]@{ id = 'role-reader'; displayName = 'Reports Reader'; isPrivileged = $false })
                }
                if ($RelativeUri -like '*roleAssignments') {
                    return @([pscustomobject]@{ principalId = 'agent-1'; roleDefinitionId = 'role-reader'; directoryScopeId = '/' })
                }
                return @()
            }

            Test-MtEntraAgentDirectoryRoles | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'reports only the privileged role when an agent has both privileged and non-privileged roles' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like 'servicePrincipals/microsoft.graph.agentIdentity') {
                    return @([pscustomobject]@{ id = 'agent-1'; displayName = 'Agent 1'; appId = 'app-1' })
                }
                if ($RelativeUri -like '*roleDefinitions') {
                    return @(
                        [pscustomobject]@{ id = 'role-appadmin'; displayName = 'Application Administrator'; isPrivileged = $true }
                        [pscustomobject]@{ id = 'role-reader'; displayName = 'Reports Reader'; isPrivileged = $false }
                    )
                }
                if ($RelativeUri -like '*roleAssignments') {
                    return @(
                        [pscustomobject]@{ principalId = 'agent-1'; roleDefinitionId = 'role-appadmin'; directoryScopeId = '/' }
                        [pscustomobject]@{ principalId = 'agent-1'; roleDefinitionId = 'role-reader'; directoryScopeId = '/' }
                    )
                }
                return @()
            }

            Test-MtEntraAgentDirectoryRoles | Should -BeFalse
            $script:TestResult | Should -Match 'Application Administrator'
            $script:TestResult | Should -Not -Match 'Reports Reader'
        }
    }

    Context 'MT.3007: Test-MtEntraAgentUserExcessiveAccess' {
        It 'passes when agent users have no directory roles or role-assignable groups' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like 'users/microsoft.graph.agentUser') {
                    return @([pscustomobject]@{ id = 'agent-user-1'; displayName = 'Agent User 1'; userPrincipalName = 'au1@contoso.com' })
                }
                if ($RelativeUri -like '*/transitiveMemberOf/*') {
                    return @([pscustomobject]@{ id = 'grp-1'; displayName = 'Standard Group'; isAssignableToRole = $false })
                }
                return @()
            }

            Test-MtEntraAgentUserExcessiveAccess | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }

        It 'reports an Agent User in a role-assignable group' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like 'users/microsoft.graph.agentUser') {
                    return @([pscustomobject]@{ id = 'agent-user-1'; displayName = 'Agent User 1'; userPrincipalName = 'au1@contoso.com' })
                }
                if ($RelativeUri -like '*/transitiveMemberOf/*') {
                    return @([pscustomobject]@{ id = 'grp-admin'; displayName = 'Tier 0 Admins'; isAssignableToRole = $true })
                }
                return @()
            }

            Test-MtEntraAgentUserExcessiveAccess | Should -BeFalse
            $script:TestResult | Should -Match 'agent-user-1'
            $script:TestResult | Should -Match 'Role-Assignable Group'
        }

        It 'passes when the only assigned role is not privileged' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like 'users/microsoft.graph.agentUser') {
                    return @([pscustomobject]@{ id = 'agent-user-1'; displayName = 'Agent User 1'; userPrincipalName = 'au1@contoso.com' })
                }
                if ($RelativeUri -like '*roleDefinitions') {
                    return @([pscustomobject]@{ id = 'role-reader'; displayName = 'Reports Reader'; isPrivileged = $false })
                }
                if ($RelativeUri -like '*roleAssignments') {
                    return @([pscustomobject]@{ principalId = 'agent-user-1'; roleDefinitionId = 'role-reader' })
                }
                if ($RelativeUri -like '*/transitiveMemberOf/*') {
                    return @([pscustomobject]@{ id = 'grp-1'; displayName = 'Standard Group'; isAssignableToRole = $false })
                }
                return @()
            }

            Test-MtEntraAgentUserExcessiveAccess | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
        }
    }
}
