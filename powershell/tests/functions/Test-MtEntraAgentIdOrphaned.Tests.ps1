Describe 'Entra Agent ID orphan checks' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    BeforeEach {
        $script:AgentTestResult = $null
        $script:AgentSkippedBecause = $null
        $script:AgentSkippedError = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedError)

            $script:AgentTestResult = $Result
            $script:AgentSkippedBecause = $SkippedBecause
            $script:AgentSkippedError = $SkippedError
        }
    }

    AfterEach {
        if ($null -ne $script:AgentTestResult) {
            $script:AgentTestResult | Should -Not -Match '`[^`]+`'
        }
    }

    Context 'Agent Identity parent checks' {
        It 'passes when every Agent Identity has a Blueprint Principal' {
            $AgentIdentity = [pscustomobject]@{
                id                     = 'identity-1'
                displayName            = 'Identity one'
                agentIdentityBlueprintId = 'blueprint-1'
            }
            $BlueprintPrincipal = [pscustomobject]@{
                id          = 'principal-1'
                displayName = 'Blueprint one'
                appId       = 'blueprint-1'
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') {
                    return @($BlueprintPrincipal)
                }
                return @($AgentIdentity)
            }

            Test-MtEntraAgentIdentityOrphaned | Should -BeTrue
            $script:AgentTestResult | Should -Match 'Well done'
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 2
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 `
                -ParameterFilter {
                $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentity' -and
                $Select -contains 'agentIdentityBlueprintId'
            }
        }

        It 'reports an Agent Identity when its Blueprint Principal is missing' {
            $AgentIdentity = [pscustomobject]@{
                id                     = 'identity-1'
                displayName            = 'Identity one'
                agentIdentityBlueprintId = 'missing-blueprint'
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') {
                    return @()
                }
                return @($AgentIdentity)
            }

            Test-MtEntraAgentIdentityOrphaned | Should -BeFalse
            $script:AgentTestResult | Should -Match 'identity-1'
            $script:AgentTestResult | Should -Match 'missing-blueprint'
        }

        It 'reports an Agent Identity when its parent reference is empty' {
            $AgentIdentity = [pscustomobject]@{
                id          = 'identity-1'
                displayName = 'Identity one'
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') {
                    return @()
                }
                return @($AgentIdentity)
            }

            Test-MtEntraAgentIdentityOrphaned | Should -BeFalse
            $script:AgentTestResult | Should -Match 'No Blueprint App ID is associated'
        }
    }

    Context 'Agent User parent checks' {
        It 'passes when every Agent User has an Agent Identity' {
            $AgentIdentity = [pscustomobject]@{
                id          = 'identity-1'
                displayName = 'Identity one'
            }
            $AgentUser = [pscustomobject]@{
                id                = 'user-1'
                displayName       = 'Agent user one'
                userPrincipalName = 'agent-user-1@contoso.com'
                identityParentId  = 'identity-1'
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like '*agentUser') {
                    return @($AgentUser)
                }
                return @($AgentIdentity)
            }

            Test-MtEntraAgentUserOrphaned | Should -BeTrue
            $script:AgentTestResult | Should -Match 'Well done'
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 2
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 `
                -ParameterFilter {
                $RelativeUri -eq 'users/microsoft.graph.agentUser' -and
                $Select -contains 'identityParentId'
            }
        }

        It 'reports an Agent User when its Agent Identity is missing' {
            $AgentUser = [pscustomobject]@{
                id                = 'user-1'
                displayName       = 'Agent user one'
                userPrincipalName = 'agent-user-1@contoso.com'
                identityParentId  = 'missing-identity'
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like '*agentUser') {
                    return @($AgentUser)
                }
                return @()
            }

            Test-MtEntraAgentUserOrphaned | Should -BeFalse
            $script:AgentTestResult | Should -Match 'user-1'
            $script:AgentTestResult | Should -Match 'missing-identity'
        }

        It 'reports an Agent User when its parent reference is empty' {
            $AgentUser = [pscustomobject]@{
                id                = 'user-1'
                displayName       = 'Agent user one'
                userPrincipalName = 'agent-user-1@contoso.com'
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($RelativeUri -like '*agentUser') {
                    return @($AgentUser)
                }
                return @()
            }

            Test-MtEntraAgentUserOrphaned | Should -BeFalse
            $script:AgentTestResult | Should -Match 'No parent Agent Identity is associated'
        }
    }

    It 'skips both checks when Graph is disconnected' {
        Mock -ModuleName Maester Test-MtConnection { return $false }

        Test-MtEntraAgentIdentityOrphaned | Should -BeNull
        $script:AgentSkippedBecause | Should -Be 'NotConnectedGraph'
        Test-MtEntraAgentUserOrphaned | Should -BeNull
        $script:AgentSkippedBecause | Should -Be 'NotConnectedGraph'
    }

    It 'passes both checks when the tenant has no Agent ID objects' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraAgentIdentityOrphaned | Should -BeTrue
        Test-MtEntraAgentUserOrphaned | Should -BeTrue
        $script:AgentTestResult | Should -Match 'Well done'
    }

    It 'skips when Graph denies the required Agent ID access' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden' }

        Test-MtEntraAgentIdentityOrphaned | Should -BeNull
        $script:AgentSkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'skips both checks when Graph retrieval fails' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph failure' }

        Test-MtEntraAgentIdentityOrphaned | Should -BeNull
        $script:AgentSkippedBecause | Should -Be 'Error'
        $script:AgentSkippedError | Should -Not -BeNullOrEmpty
        Test-MtEntraAgentUserOrphaned | Should -BeNull
        $script:AgentSkippedBecause | Should -Be 'Error'
    }
}
