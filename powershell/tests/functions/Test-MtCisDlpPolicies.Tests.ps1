BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisDlpPoliciesEnabled, Test-MtCisTeamsDlpPolicy, Test-MtCisDlpPoliciesCopilot

    function Get-DlpPolicyFixture {
        param([hashtable] $Properties = @{})
        $policy = @{
            Name = 'DLP policy'
            Mode = 'Enable'
            EnforcementPlanes = @()
            Workload = 'Exchange'
            ExchangeLocation = @()
            SharePointLocation = @()
            OneDriveLocation = @()
            TeamsLocation = @()
            TeamsLocationException = @()
            PolicyRBACScopes = @()
            IsSimulationPolicy = $false
            MicrosoftCopilotLocation = @()
            Locations = @()
            LocationInclusions = @('All')
            LocationExclusions = @()
        }
        foreach ($key in $Properties.Keys) { $policy[$key] = $Properties[$key] }
        [pscustomobject]$policy
    }

    function Get-DlpRuleFixture {
        param([hashtable] $Properties = @{})
        $rule = @{
            ParentPolicyName = 'DLP policy'
            Disabled = $false
            Mode = 'Enforce'
            ContentContainsSensitiveInformation = @(@{ Name = 'Credit Card Number' })
            AdvancedRule = $null
            BlockAccess = $true
            RestrictAccess = @()
            RestrictWebGrounding = $false
        }
        foreach ($key in $Properties.Keys) { $rule[$key] = $Properties[$key] }
        [pscustomobject]$rule
    }
}

Describe 'CIS 3.2 DLP audit alignment' {
    BeforeEach {
        $script:Result = $null
        $script:Investigate = $false
        $script:Policies = @()
        $script:Rules = @()
        Mock -ModuleName Maester Get-MtExo {
            if ($Request -eq 'DlpCompliancePolicy') { $script:Policies }
            elseif ($Request -eq 'DlpComplianceRule') { $script:Rules }
            else { throw "Unexpected request: $Request" }
        }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, [switch] $Investigate)
            $script:Result = $Result
            $script:Investigate = $Investigate.IsPresent
        }
    }

    Context '3.2.1 required workload locations' {
        It 'accepts a defined <Location> (<Shape>)' -ForEach @(
            foreach ($location in 'ExchangeLocation', 'SharePointLocation', 'OneDriveLocation', 'TeamsLocation') {
                @{ Location = $location; Shape = 'string'; Value = @('All') }
                @{ Location = $location; Shape = 'object'; Value = @([pscustomobject]@{ ImmutableIdentity = 'target-id'; DisplayName = 'Target' }) }
            }
        ) {
            $script:Policies = @(Get-DlpPolicyFixture -Properties @{ $Location = $Value })

            Test-MtCisDlpPoliciesEnabled | Should -BeTrue
            $script:Investigate | Should -BeFalse
            $script:Result | Should -Match $Location
        }

        It 'fails with <Case>' -ForEach @(
            @{ Case = 'no policies'; Properties = $null }
            @{ Case = 'no required location'; Properties = @{} }
            @{ Case = 'null and empty locations'; Properties = @{ ExchangeLocation = $null; SharePointLocation = @($null); OneDriveLocation = @('') } }
            @{ Case = 'a disabled policy'; Properties = @{ Mode = 'Disable'; ExchangeLocation = @('All') } }
            @{ Case = 'a simulation mode'; Properties = @{ Mode = 'TestWithNotifications'; ExchangeLocation = @('All') } }
            @{ Case = 'a Copilot-only policy'; Properties = @{ EnforcementPlanes = @('CopilotExperiences') } }
            @{ Case = 'another workload only'; Properties = @{ Workload = 'Endpoint'; Locations = @('Endpoint') } }
        ) {
            if ($null -ne $Properties) { $script:Policies = @(Get-DlpPolicyFixture -Properties $Properties) }

            Test-MtCisDlpPoliciesEnabled | Should -BeFalse
            $script:Investigate | Should -BeFalse
        }

        It 'does not combine an enabled policy without locations with a disabled policy with locations' {
            $script:Policies = @(
                Get-DlpPolicyFixture
                Get-DlpPolicyFixture -Properties @{ Mode = 'Disable'; ExchangeLocation = @('All') }
            )

            Test-MtCisDlpPoliciesEnabled | Should -BeFalse
        }

        It 'accepts a mixed Copilot and required-workload policy' {
            $script:Policies = @(Get-DlpPolicyFixture -Properties @{ EnforcementPlanes = @('CopilotExperiences'); TeamsLocation = @('All') })

            Test-MtCisDlpPoliciesEnabled | Should -BeTrue
        }
    }

    Context '3.2.2 Teams all accounts and permitted exceptions' {
        BeforeEach {
            $script:Policies = @(Get-DlpPolicyFixture -Properties @{ Workload = 'Exchange, Teams'; TeamsLocation = @([pscustomobject]@{ ImmutableIdentity = 'All' }) })
            $script:Rules = @(Get-DlpRuleFixture)
        }

        It 'passes without exceptions' {
            Test-MtCisTeamsDlpPolicy | Should -BeTrue
            $script:Investigate | Should -BeFalse
        }

        It 'fails when no enabled rule exists, even with permitted exceptions' {
            $script:Rules = @()
            $script:Policies[0].TeamsLocationException = @('allowed@contoso.com')

            Test-MtCisTeamsDlpPolicy | Should -BeFalse
            $script:Investigate | Should -BeFalse
        }

        It 'fails when the only matching rule is disabled' {
            $script:Rules = @(Get-DlpRuleFixture -Properties @{ Disabled = $true })

            Test-MtCisTeamsDlpPolicy | Should -BeFalse
            $script:Investigate | Should -BeFalse
        }

        It 'does not count an enabled rule for another policy' {
            $script:Rules = @(Get-DlpRuleFixture -Properties @{ ParentPolicyName = 'Other policy' })

            Test-MtCisTeamsDlpPolicy | Should -BeFalse
            $script:Investigate | Should -BeFalse
        }

        It 'accepts string and DisplayName representations of All' -ForEach @(
            @{ Value = @('All') }
            @{ Value = @([pscustomobject]@{ DisplayName = 'All' }) }
        ) {
            $script:Policies[0].TeamsLocation = $Value

            Test-MtCisTeamsDlpPolicy | Should -BeTrue
        }

        It 'accepts a mixed Copilot and Teams policy' {
            $script:Policies[0].EnforcementPlanes = @('CopilotExperiences')

            Test-MtCisTeamsDlpPolicy | Should -BeTrue
        }

        It 'marks exceptions for investigation and lists their identities' {
            $script:Policies[0].TeamsLocationException = @('allowed@contoso.com', [pscustomobject]@{ ImmutableIdentity = 'group-id'; DisplayName = 'Approved group' })

            Test-MtCisTeamsDlpPolicy | Should -BeTrue
            $script:Investigate | Should -BeTrue
            $script:Result | Should -Match ([regex]::Escape((Get-MtSafeMarkdown 'allowed@contoso.com')))
            $script:Result | Should -Match 'group-id'
            $script:Result | Should -Match 'Approved group'
            $script:Result | Should -Match 'permitted by the organization'
        }

        It 'passes if another qualifying policy has no exceptions' {
            $script:Policies[0].TeamsLocationException = @('allowed@contoso.com')
            $script:Policies += Get-DlpPolicyFixture -Properties @{ Name = 'Unrestricted'; Workload = 'Teams'; TeamsLocation = @('All') }
            $script:Rules += Get-DlpRuleFixture -Properties @{ ParentPolicyName = 'Unrestricted' }

            Test-MtCisTeamsDlpPolicy | Should -BeTrue
            $script:Investigate | Should -BeFalse
        }

        It 'fails rather than investigates <Case>, even with exceptions' -ForEach @(
            @{ Case = 'a disabled policy'; Property = 'Mode'; Value = 'Disable' }
            @{ Case = 'a non-Teams workload'; Property = 'Workload'; Value = 'Exchange' }
            @{ Case = 'selected accounts'; Property = 'TeamsLocation'; Value = @('user@contoso.com') }
            @{ Case = 'an unknown location'; Property = 'TeamsLocation'; Value = @() }
            @{ Case = 'an administrative-unit scope'; Property = 'PolicyRBACScopes'; Value = @('unit-id') }
        ) {
            $script:Policies[0].$Property = $Value
            $script:Policies[0].TeamsLocationException = @('allowed@contoso.com')

            Test-MtCisTeamsDlpPolicy | Should -BeFalse
            $script:Investigate | Should -BeFalse
        }

        It 'fails when no policy is returned' {
            $script:Policies = @()

            Test-MtCisTeamsDlpPolicy | Should -BeFalse
        }
    }

    Context '3.2.3 Copilot rules and exclusion evidence' {
        BeforeEach {
            $script:Policies = @(Get-DlpPolicyFixture -Properties @{ EnforcementPlanes = @('CopilotExperiences'); Workload = 'Copilot' })
            $script:Rules = @(Get-DlpRuleFixture)
        }

        It 'accepts an enforcing sensitive-information rule' {
            Test-MtCisDlpPoliciesCopilot | Should -BeTrue
            $script:Investigate | Should -BeFalse
        }

        It 'accepts sensitivity-label groups in ContentContainsSensitiveInformation' {
            $script:Rules[0].ContentContainsSensitiveInformation = @(@{
                    operator = 'And'
                    groups = @(@{ operator = 'Or'; name = 'Default'; labels = @(@{ name = 'Confidential'; type = 'Sensitivity' }) })
                })

            Test-MtCisDlpPoliciesCopilot | Should -BeTrue
            $script:Investigate | Should -BeFalse
        }

        It 'accepts label conditions in AdvancedRule' {
            $script:Rules[0].ContentContainsSensitiveInformation = @()
            $script:Rules[0].AdvancedRule = '{"Version":"1.0","Condition":{"Operator":"And","SubConditions":[{"ConditionName":"ContentContainsSensitiveInformation","Value":[{"operator":"And","groups":[{"operator":"Or","name":"Default","labels":[{"name":"Confidential","type":"Sensitivity"}]}]}]}]}}'

            Test-MtCisDlpPoliciesCopilot | Should -BeTrue
        }

        It 'accepts the <Action> restriction' -ForEach @(
            @{ Action = 'RestrictAccess'; Value = @('Block') }
            @{ Action = 'RestrictWebGrounding'; Value = $true }
        ) {
            $script:Rules[0].BlockAccess = $false
            $script:Rules[0].$Action = $Value

            Test-MtCisDlpPoliciesCopilot | Should -BeTrue
        }

        It 'fails for <Case>' -ForEach @(
            @{ Case = 'no rules'; Properties = $null }
            @{ Case = 'a disabled rule'; Properties = @{ Disabled = $true } }
            @{ Case = 'an audit-only rule'; Properties = @{ Mode = 'TestWithNotifications' } }
            @{ Case = 'a rule for another policy'; Properties = @{ ParentPolicyName = 'Other policy' } }
            @{ Case = 'no sensitive condition'; Properties = @{ ContentContainsSensitiveInformation = @() } }
            @{ Case = 'no restrictive action'; Properties = @{ BlockAccess = $false; RestrictAccess = @('None') } }
        ) {
            $script:Rules = @()
            if ($null -ne $Properties) { $script:Rules = @(Get-DlpRuleFixture -Properties $Properties) }

            Test-MtCisDlpPoliciesCopilot | Should -BeFalse
            $script:Investigate | Should -BeFalse
        }

        It 'fails rather than investigates <Case>' -ForEach @(
            @{ Case = 'a disabled policy'; Properties = @{ Mode = 'Disable' } }
            @{ Case = 'a simulation policy'; Properties = @{ IsSimulationPolicy = $true } }
            @{ Case = 'an administrative-unit scope'; Properties = @{ PolicyRBACScopes = @('unit-id') } }
            @{ Case = 'selected accounts'; Properties = @{ LocationInclusions = @('user@contoso.com') } }
            @{ Case = 'no Copilot location'; Properties = @{ EnforcementPlanes = @(); Workload = 'Exchange' } }
        ) {
            foreach ($key in $Properties.Keys) { $script:Policies[0].$key = $Properties[$key] }
            $script:Policies[0].LocationExclusions = @('allowed@contoso.com')

            Test-MtCisDlpPoliciesCopilot | Should -BeFalse
            $script:Investigate | Should -BeFalse
        }

        It 'investigates an unknown inclusion scope' {
            $script:Policies[0].LocationInclusions = @()

            Test-MtCisDlpPoliciesCopilot | Should -BeTrue
            $script:Investigate | Should -BeTrue
        }

        It 'lists top-level exclusions for manual approval' {
            $script:Policies[0].LocationExclusions = @('allowed@contoso.com', [pscustomobject]@{ ImmutableIdentity = 'excluded-id'; DisplayName = 'Approved group' })

            Test-MtCisDlpPoliciesCopilot | Should -BeTrue
            $script:Investigate | Should -BeTrue
            $script:Result | Should -Match ([regex]::Escape((Get-MtSafeMarkdown 'allowed@contoso.com')))
            $script:Result | Should -Match 'excluded-id'
            $script:Result | Should -Match 'Approved group'
        }

        It 'lists exclusions from <Field> without borrowing another workload scope' -ForEach @(
            @{ Field = 'Locations' }
            @{ Field = 'MicrosoftCopilotLocation' }
        ) {
            $copilot = [pscustomobject]@{ Location = '470f2276-e011-4e9d-a6ec-20768be3a4b0'; Inclusions = @('All'); Exclusions = @('copilot-exclusion-id') }
            $script:Policies[0].Locations = @([pscustomobject]@{ Location = 'Exchange'; Inclusions = @('All'); Exclusions = @('exchange-exclusion-id') })
            if ($Field -eq 'Locations') {
                $script:Policies[0].Locations += $copilot
                $script:Policies[0].Locations = ConvertTo-Json -InputObject $script:Policies[0].Locations -Depth 10 -Compress
            }
            else { $script:Policies[0].MicrosoftCopilotLocation = @($copilot) }

            Test-MtCisDlpPoliciesCopilot | Should -BeTrue
            $script:Investigate | Should -BeTrue
            $script:Result | Should -Match 'copilot-exclusion-id'
            $script:Result | Should -Not -Match 'exchange-exclusion-id'
        }

        It 'does not borrow All from Exchange in a mixed-location policy' {
            $script:Policies[0].Locations = @(
                [pscustomobject]@{ Location = 'Exchange'; Inclusions = @('All') }
                [pscustomobject]@{ Location = 'Copilot'; Inclusions = @('selected-user') }
            )

            Test-MtCisDlpPoliciesCopilot | Should -BeFalse
        }

        It 'passes if another qualifying Copilot policy has no exclusions' {
            $script:Policies[0].LocationExclusions = @('allowed@contoso.com')
            $script:Policies += Get-DlpPolicyFixture -Properties @{ Name = 'Unrestricted'; EnforcementPlanes = @('CopilotExperiences'); Workload = 'Copilot' }
            $script:Rules += Get-DlpRuleFixture -Properties @{ ParentPolicyName = 'Unrestricted' }

            Test-MtCisDlpPoliciesCopilot | Should -BeTrue
            $script:Investigate | Should -BeFalse
        }

        It 'fails when no policy is returned' {
            $script:Policies = @()

            Test-MtCisDlpPoliciesCopilot | Should -BeFalse
        }
    }

    Context 'safe result evidence' {
        It 'escapes tenant-controlled names, modes and exceptions for <Check>' -ForEach @(
            @{ Check = 'Test-MtCisDlpPoliciesEnabled' }
            @{ Check = 'Test-MtCisTeamsDlpPolicy' }
            @{ Check = 'Test-MtCisDlpPoliciesCopilot' }
        ) {
            $name = '![x](https://example.com)|$&'
            $exception = 'excluded@contoso.com|[link](https://example.com)'
            $mode = 'Disabled|[link](https://example.com)'
            $script:Policies = @(Get-DlpPolicyFixture -Properties @{
                    Name = $name; Mode = $mode; Workload = 'Teams'
                    TeamsLocation = @('All'); TeamsLocationException = @($exception)
                    EnforcementPlanes = @('CopilotExperiences'); LocationExclusions = @($exception)
                })

            & $Check | Should -BeFalse
            $script:Result | Should -Match ([regex]::Escape((Get-MtSafeMarkdown $name)))
            $script:Result | Should -Match ([regex]::Escape((Get-MtSafeMarkdown $mode)))
            if ($Check -ne 'Test-MtCisDlpPoliciesEnabled') {
                $script:Result | Should -Match ([regex]::Escape((Get-MtSafeMarkdown $exception)))
            }
            $script:Result | Should -Not -Match '%TestResult%'
        }
    }
}
