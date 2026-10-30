# The ASD checks that run another suite's test, and the helpers the ASD checks read through. Graph is mocked.

BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue }

Describe 'ASD checks and the tests they run' {
    It 'CISA 3.1 and ASD.ISM-1872 accept the built-in strength by ID and a phishing-resistant custom one, and reject a weak one' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            $base = { param($strength) [pscustomobject]@{ state = 'enabled'; displayName = 'p'; conditions = [pscustomobject]@{ applications = [pscustomobject]@{ includeApplications = @('All') }; users = [pscustomobject]@{ includeUsers = @('All') } }; grantControls = [pscustomobject]@{ authenticationStrength = $strength } } }
            Mock Get-MtConditionalAccessPolicy { & $base ([pscustomobject]@{ id = '00000000-0000-0000-0000-000000000004'; displayName = 'Renamed'; allowedCombinations = @() }) }
            Test-MtAsdPhishingResistantMfa | Should -BeTrue
            Mock Get-MtConditionalAccessPolicy { & $base ([pscustomobject]@{ id = 'custom'; displayName = 'Custom'; allowedCombinations = @('fido2', 'windowsHelloForBusiness') }) }
            Test-MtCisaPhishResistant | Should -BeTrue
            Mock Get-MtConditionalAccessPolicy { & $base ([pscustomobject]@{ id = 'custom2'; displayName = 'Phishing-resistant MFA'; allowedCombinations = @('fido2', 'microsoftAuthenticatorPush,password') }) }
            Test-MtCisaPhishResistant | Should -BeFalse
        }
    }
    It 'ASD.ISM-1403 passes 5 and fails 10 and the default' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            Mock Invoke-MtGraphRequest { @([pscustomobject]@{ templateId = '5cf42378-d67d-4f36-ba46-e8b86229381d'; values = @([pscustomobject]@{ name = 'LockoutThreshold'; value = '5' }) }) }
            Test-MtAsdSmartLockoutThreshold | Should -BeTrue
            Mock Invoke-MtGraphRequest { @([pscustomobject]@{ templateId = '5cf42378-d67d-4f36-ba46-e8b86229381d'; values = @([pscustomobject]@{ name = 'LockoutThreshold'; value = '10' }) }) }
            Test-MtAsdSmartLockoutThreshold | Should -BeFalse
            Test-MtCisSmartLockoutThreshold | Should -BeTrue
            Mock Invoke-MtGraphRequest { @() }
            Test-MtAsdSmartLockoutThreshold | Should -BeFalse
        }
    }
    It 'ISM-1667 needs both rules on Block in an assigned policy' {
        InModuleScope Maester {
            Mock Add-MtTestResultDetail {}
            $p = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules_'
            Mock Get-MtIntuneConfigurationPolicySetting { @(
                    [pscustomobject]@{ PolicyId = '1'; PolicyName = 'ASR'; IsAssigned = $true; SettingDefinitionId = "${p}blockallofficeapplicationsfromcreatingchildprocesses"; Value = "${p}blockallofficeapplicationsfromcreatingchildprocesses_block" }
                ) }
            Test-MtAsdOfficeChildProcessesBlocked | Should -BeFalse
            Mock Get-MtIntuneConfigurationPolicySetting { @(
                    [pscustomobject]@{ PolicyId = '1'; PolicyName = 'ASR'; IsAssigned = $true; SettingDefinitionId = "${p}blockallofficeapplicationsfromcreatingchildprocesses"; Value = "${p}blockallofficeapplicationsfromcreatingchildprocesses_block" }
                    [pscustomobject]@{ PolicyId = '1'; PolicyName = 'ASR'; IsAssigned = $true; SettingDefinitionId = "${p}blockofficecommunicationappfromcreatingchildprocesses"; Value = "${p}blockofficecommunicationappfromcreatingchildprocesses_audit" }
                ) }
            Test-MtAsdOfficeChildProcessesBlocked | Should -BeFalse
            Mock Get-MtIntuneConfigurationPolicySetting { @(
                    [pscustomobject]@{ PolicyId = '1'; PolicyName = 'ASR'; IsAssigned = $true; SettingDefinitionId = "${p}blockallofficeapplicationsfromcreatingchildprocesses"; Value = "${p}blockallofficeapplicationsfromcreatingchildprocesses_block" }
                    [pscustomobject]@{ PolicyId = '2'; PolicyName = 'ASR2'; IsAssigned = $true; SettingDefinitionId = "${p}blockofficecommunicationappfromcreatingchildprocesses"; Value = "${p}blockofficecommunicationappfromcreatingchildprocesses_block" }
                ) }
            Test-MtAsdOfficeChildProcessesBlocked | Should -BeTrue
        }
    }
    It 'Get-MtPrivilegedRoleUser expands role-assignable groups and leaves out emergency accounts' {
        InModuleScope Maester {
            Mock Invoke-MtGraphRequest { @([pscustomobject]@{ id = 'ga'; displayName = 'Global Administrator' }) } -ParameterFilter { $RelativeUri -eq 'roleManagement/directory/roleDefinitions' }
            Mock Get-MtDirectoryRoleAssignment { [pscustomobject]@{ Assignments = @(
                        [pscustomobject]@{ roleDefinitionId = 'ga'; principalId = 'u1'; principal = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'u1' } }
                        [pscustomobject]@{ roleDefinitionId = 'ga'; principalId = 'g1'; principal = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.group'; id = '11111111-1111-1111-1111-111111111111' } }
                        [pscustomobject]@{ roleDefinitionId = 'ga'; principalId = 'bg'; principal = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'bg' } }
                        [pscustomobject]@{ roleDefinitionId = 'reader'; principalId = 'u9'; principal = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'u9' } }
                    ) } }
            Mock Get-MtGroupMember { @([pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'u2' }) }
            Mock Get-MtEmergencyAccessAccount { @([pscustomobject]@{ ObjectId = 'bg' }) }
            $r = Get-MtPrivilegedRoleUser -ExcludeEmergencyAccessAccount
            @($r.Keys | Sort-Object) | Should -Be @('u1', 'u2')
            $r['u2'] | Should -Be @('Global Administrator')
            @((Get-MtPrivilegedRoleUser).Keys | Sort-Object) | Should -Be @('bg', 'u1', 'u2')
        }
    }
}
