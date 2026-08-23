Describe 'Entra Agent Identity Blueprint orphan check' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    BeforeEach {
        $script:BlueprintResult = $null
        $script:BlueprintSkippedBecause = $null
        $script:BlueprintSkippedError = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedError)

            $script:BlueprintResult = $Result
            $script:BlueprintSkippedBecause = $SkippedBecause
            $script:BlueprintSkippedError = $SkippedError
        }
    }

    AfterEach {
        if ($null -ne $script:BlueprintResult) {
            $script:BlueprintResult | Should -Not -Match '`[^`]+`'
        }
    }

    It 'passes when every Blueprint Principal has an actual Blueprint' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch -Wildcard ($RelativeUri) {
                '*agentIdentityBlueprintPrincipal' {
                    return @([pscustomobject]@{ id = 'principal-1'; appId = 'app-1' })
                }
                'applications/*' {
                    return @([pscustomobject]@{ id = 'blueprint-1'; appId = 'app-1' })
                }
                default {
                    return @([pscustomobject]@{
                            id = 'identity-1'; agentIdentityBlueprintId = 'app-1'
                        })
                }
            }
        }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeTrue
        $script:BlueprintResult | Should -Match 'Well done'
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 3
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 3 `
            -ParameterFilter { $ApiVersion -eq 'v1.0' }
    }

    It 'reports a Blueprint Principal when its actual Blueprint is missing' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch -Wildcard ($RelativeUri) {
                '*agentIdentityBlueprintPrincipal' {
                    return @([pscustomobject]@{
                            id = 'principal-1'; displayName = 'Principal one'; appId = 'app-1'
                        })
                }
                'applications/*' { return @() }
                default {
                    return @([pscustomobject]@{
                            id = 'identity-1'; agentIdentityBlueprintId = 'app-1'
                        })
                }
            }
        }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeFalse
        $script:BlueprintResult | Should -Match 'principal-1'
        $script:BlueprintResult | Should -Match 'identity-1'
        $script:BlueprintResult | Should -Match 'app-1'
    }

    It 'leaves a missing Blueprint Principal relationship to MT.1200' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') { return @() }
            if ($RelativeUri -like 'applications/*') { return @() }
            return @([pscustomobject]@{
                    id = 'identity-1'; agentIdentityBlueprintId = 'missing-principal'
                })
        }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeTrue
        $script:BlueprintResult | Should -Not -Match 'identity-1'
    }

    It 'passes when the tenant has no Agent ID objects' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeTrue
    }

    It 'requests the required properties from each v1.0 endpoint' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeTrue
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 `
            -ParameterFilter {
                $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentity' -and
                $ApiVersion -eq 'v1.0' -and $Select -contains 'agentIdentityBlueprintId'
            }
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 `
            -ParameterFilter {
                $RelativeUri -eq
                'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' -and
                $ApiVersion -eq 'v1.0' -and $Select -contains 'appId'
            }
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 `
            -ParameterFilter {
                $RelativeUri -eq 'applications/microsoft.graph.agentIdentityBlueprint' -and
                $ApiVersion -eq 'v1.0' -and $Select -contains 'appId'
            }
    }

    It 'skips when Graph is disconnected' {
        Mock -ModuleName Maester Test-MtConnection { return $false }
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Should not be called' }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeNull
        $script:BlueprintSkippedBecause | Should -Be 'NotConnectedGraph'
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 0
    }

    It 'skips when Graph denies Blueprint access' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden' }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeNull
        $script:BlueprintSkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'skips when a required Graph property is missing' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($RelativeUri -like '*agentIdentityBlueprintPrincipal') {
                return @([pscustomobject]@{ id = 'principal-1' })
            }
            return @()
        }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeNull
        $script:BlueprintSkippedBecause | Should -Be 'Error'
    }

    It 'skips when Graph retrieval fails' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph failure' }

        Test-MtEntraAgentBlueprintOrphaned | Should -BeNull
        $script:BlueprintSkippedBecause | Should -Be 'Error'
        $script:BlueprintSkippedError | Should -Not -BeNullOrEmpty
    }
}
