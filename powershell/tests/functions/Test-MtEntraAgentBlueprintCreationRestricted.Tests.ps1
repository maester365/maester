Describe 'Entra agent blueprint creation check' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtEntraAgentBlueprintCreationRestricted

        function Get-Policy {
            param([hashtable] $DefaultUserRolePermissions)
            [pscustomobject]@{ defaultUserRolePermissions = [pscustomobject]$DefaultUserRolePermissions }
        }
    }

    BeforeEach {
        $script:Result = $null
        $script:SkippedBecause = $null
        $script:SkippedReason = $null

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedCustomReason)

            $script:Result = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedReason = $SkippedCustomReason
        }
    }

    It 'passes when default users cannot create agent blueprints' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            Get-Policy @{ allowedToCreateAgentIdentityBlueprints = $false }
        }

        Test-MtEntraAgentBlueprintCreationRestricted | Should -BeTrue
        $script:Result | Should -Match 'Well done'
        $script:SkippedBecause | Should -BeNullOrEmpty
    }

    It 'fails and names the setting to turn off when default users can create agent blueprints' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            Get-Policy @{ allowedToCreateAgentIdentityBlueprints = $true }
        }

        Test-MtEntraAgentBlueprintCreationRestricted | Should -BeFalse
        $script:Result | Should -Match 'can create agent blueprints'
        $script:Result | Should -Match 'Users can register agent identity blueprints'
        $script:Result | Should -Not -Match 'Agent ID Developer'
    }

    It 'reads the setting from the beta authorization policy' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            Get-Policy @{ allowedToCreateAgentIdentityBlueprints = $false }
        }

        $null = Test-MtEntraAgentBlueprintCreationRestricted

        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 -ParameterFilter {
            $ApiVersion -eq 'beta' -and $RelativeUri -eq 'policies/authorizationPolicy'
        }
    }

    It 'is skipped when the tenant does not return the setting yet' -ForEach @(
        @{ Case = 'the property is missing'; Policy = { Get-Policy @{ allowedToCreateApps = $true } } }
        @{ Case = 'the property is null'; Policy = { Get-Policy @{ allowedToCreateAgentIdentityBlueprints = $null } } }
        @{ Case = 'there are no default user permissions'; Policy = { [pscustomobject]@{} } }
    ) {
        Mock -ModuleName Maester Invoke-MtGraphRequest { & $Policy }.GetNewClosure()

        Test-MtEntraAgentBlueprintCreationRestricted | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'Custom'
        $script:SkippedReason | Should -Match '4 November 2026'
        $script:Result | Should -BeNullOrEmpty
    }

    It 'is skipped as not authorized on a 403 response' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            $Exception = [System.Exception]::new('Forbidden')
            $Response = [pscustomobject]@{ StatusCode = 403 }
            $Exception | Add-Member -NotePropertyName Response -NotePropertyValue $Response
            throw $Exception
        }

        Test-MtEntraAgentBlueprintCreationRestricted | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'is skipped with the error on any other failure' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph is down' }

        Test-MtEntraAgentBlueprintCreationRestricted | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'Error'
    }
}
