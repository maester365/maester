BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    InModuleScope Maester {
        $script:PlanReportingPreviousPortalUrl = $__MtSession.AdminPortalUrl
        $__MtSession.AdminPortalUrl = @{ Entra = 'https://entra.microsoft.com/' }
    }
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name ConvertTo-MtConditionalAccessPolicy, Merge-MtConditionalAccessCondition, Test-MtCaDeviceComplianceExists
    $script:planFixture = Get-Content "$PSScriptRoot/../fixtures/conditional-access-plans/plan.json" -Raw | ConvertFrom-Json
    $script:ruleFixture = (Get-Content "$PSScriptRoot/../fixtures/conditional-access-plans/rules.json" -Raw | ConvertFrom-Json).value
    $script:evaluatedFixture = (Get-Content "$PSScriptRoot/../fixtures/conditional-access-plans/requester-windows-resource-a.json" -Raw | ConvertFrom-Json).value
    function New-PlanFixture {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Returns a fresh in-memory fixture copy without changing external state.')]
        [CmdletBinding()]
        param()

        $script:planFixture | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    }
    function New-RuleFixture {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Returns a fresh in-memory fixture copy without changing external state.')]
        [CmdletBinding()]
        param()

        $script:ruleFixture[1] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    }
}

Describe 'Conditional Access plan inventory' {
    BeforeEach {
        Mock Invoke-MtGraphRequest -ModuleName Maester { throw "Unexpected endpoint: $RelativeUri" }
        Mock Invoke-MtGraphRequest -ModuleName Maester { @() } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        Mock Invoke-MtGraphRequest -ModuleName Maester {
            [pscustomobject]@{ id = 'standalone'; state = 'enabled'; displayName = 'Standalone' }
        } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/policies' }
    }

    It 'Accepts an empty plans inventory alongside standalone policies' {
        $result = @(Get-MtConditionalAccessPolicy)
        $result.Count | Should -Be 1
        $result[0].id | Should -Be standalone
    }

    It 'Does not invent plans when both inventories are empty' {
        Mock Invoke-MtGraphRequest -ModuleName Maester { @() } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/policies' }
        @(Get-MtConditionalAccessPolicy).Count | Should -Be 0
    }

    It 'Offers an explicit standalone inventory without any preview request' {
        @(Get-MtConditionalAccessPolicy -StandaloneOnly).Count | Should -Be 1
        Should -Not -Invoke Invoke-MtGraphRequest -ModuleName Maester -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
    }

    It 'Propagates forbidden plans access rather than silently returning standalone-only data' {
        Mock Invoke-MtGraphRequest -ModuleName Maester { throw '403 Forbidden' } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        { Get-MtConditionalAccessPolicy } | Should -Throw '*403 Forbidden*'
    }

    It 'Propagates a failed rule read' {
        Mock Invoke-MtGraphRequest -ModuleName Maester { [pscustomobject]@{ id = 'plan' } } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        Mock Invoke-MtGraphRequest -ModuleName Maester { throw '503 Unavailable' } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans/plan/rules' }
        { Get-MtConditionalAccessPolicy } | Should -Throw '*503 Unavailable*'
    }

    It 'Rejects a malformed plan instead of treating it as an empty inventory' {
        Mock Invoke-MtGraphRequest -ModuleName Maester { [pscustomobject]@{ displayName = 'Missing ID' } } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        { Get-MtConditionalAccessPolicyPlan } | Should -Throw '*without an ID*'
    }

    It 'Reads every rule and leaves cached plan objects unchanged' {
        $script:cachedPlan = [pscustomobject]@{ id = 'plan'; displayName = 'Plan'; owners = @('owner') }
        Mock Invoke-MtGraphRequest -ModuleName Maester { $script:cachedPlan } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        Mock Invoke-MtGraphRequest -ModuleName Maester { @([pscustomobject]@{ id = 'rule-a' }, [pscustomobject]@{ id = 'rule-b' }) } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans/plan/rules' }
        $result = @(Get-MtConditionalAccessPolicyPlan)
        $result[0].rules.Count | Should -Be 2
        $script:cachedPlan.PSObject.Properties.Name | Should -Not -Contain rules
        $result[0].rules[0].controls | Should -BeNullOrEmpty
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 2 -Exactly -ParameterFilter { -not $DisableCache -and $ApiVersion -eq 'beta' }
    }

    It 'Reads owner metadata without requesting child rules' {
        Mock Invoke-MtGraphRequest -ModuleName Maester { [pscustomobject]@{ id = 'plan'; owners = @('owner') } } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        $result = @(Get-MtConditionalAccessPolicyPlan -MetadataOnly)
        $result[0].owners | Should -Be @('owner')
        Should -Not -Invoke Invoke-MtGraphRequest -ModuleName Maester -ParameterFilter { $RelativeUri -like '*/rules' }
    }

    It 'Retains the real rule ID and state in a combined inventory' {
        Mock Invoke-MtGraphRequest -ModuleName Maester { $script:planFixture } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        Mock Invoke-MtGraphRequest -ModuleName Maester { $script:ruleFixture } -ParameterFilter { $RelativeUri -like 'identity/conditionalAccess/plans/*/rules' }
        $result = @(Get-MtConditionalAccessPolicy)
        $result.Count | Should -Be 3
        $result[1].id | Should -Be $script:ruleFixture[0].id
        $result[1].state | Should -Be enabledForReportingButNotEnforced
        $result[1].sourceType | Should -Be PolicyPlanRule
        $result[1].planId | Should -Be $script:planFixture.id
    }
}

Describe 'Plan rule projection' {
    It 'Matches inherited targeting and controls in anonymized live Entra evaluation fixtures' {
        foreach ($rule in $script:ruleFixture) {
            $policy = ConvertTo-MtConditionalAccessPolicy -Plan $script:planFixture -Rule $rule
            $engine = $script:evaluatedFixture | Where-Object id -EQ $rule.id
            $policy.conditions.users | ConvertTo-Json -Depth 30 -Compress | Should -Be ($engine.conditions.users | ConvertTo-Json -Depth 30 -Compress)
            $expectedApplications = [ordered]@{}
            foreach ($key in $policy.conditions.applications.Keys) { $expectedApplications[$key] = $engine.conditions.applications.$key }
            $policy.conditions.applications | ConvertTo-Json -Depth 30 -Compress | Should -Be ($expectedApplications | ConvertTo-Json -Depth 30 -Compress)
            $policy.conditions.platforms | ConvertTo-Json -Depth 30 -Compress | Should -Be ($engine.conditions.platforms | ConvertTo-Json -Depth 30 -Compress)
            $policy.grantControls.builtInControls | Should -Be $engine.grantControls.builtInControls
            $policy.grantControls.operator | Should -Be $engine.grantControls.operator
            $policy.state | Should -Be $engine.state
        }
    }

    It 'Accumulates shared and per-rule exclusions without mutating either source' {
        $plan = New-PlanFixture
        $rule = New-RuleFixture
        $rule.conditions.users = [pscustomobject]@{ excludeUsers = @('rule-exclusion') }
        $beforePlan = $plan | ConvertTo-Json -Depth 100 -Compress
        $beforeRule = $rule | ConvertTo-Json -Depth 100 -Compress
        $policy = ConvertTo-MtConditionalAccessPolicy -Plan $plan -Rule $rule
        $policy.conditions.users.excludeUsers | Should -Contain $plan.sharedConditions.users.excludeUsers[0]
        $policy.conditions.users.excludeUsers | Should -Contain rule-exclusion
        ($plan | ConvertTo-Json -Depth 100 -Compress) | Should -Be $beforePlan
        ($rule | ConvertTo-Json -Depth 100 -Compress) | Should -Be $beforeRule
    }

    It 'Projects a rule without reading sibling rule payloads' {
        $result = InModuleScope Maester -Parameters @{ Plan = (New-PlanFixture); Rule = (New-RuleFixture) } {
            param($Plan, $Rule)
            $script:ProjectionSiblingReads = 0
            $Plan.PSObject.Properties.Remove('rules')
            $Plan | Add-Member -MemberType ScriptProperty -Name rules -Value {
                $script:ProjectionSiblingReads++
                @([pscustomobject]@{ id = 'unrelated-rule' })
            }
            try {
                $policy = ConvertTo-MtConditionalAccessPolicy -Plan $Plan -Rule $Rule
                [pscustomobject]@{ Reads = $script:ProjectionSiblingReads; Policy = $policy }
            } finally {
                Remove-Variable ProjectionSiblingReads -Scope Script
            }
        }
        $result.Reads | Should -Be 0
        $result.Policy.id | Should -Be $script:ruleFixture[1].id
        $result.Policy.conditions.users.excludeUsers | Should -Be $script:planFixture.sharedConditions.users.excludeUsers
    }

    It 'Keeps shared conditions independent of the cached parent after projection' {
        $plan = New-PlanFixture
        $before = $plan | ConvertTo-Json -Depth 100 -Compress
        $policy = ConvertTo-MtConditionalAccessPolicy -Plan $plan -Rule (New-RuleFixture)
        $policy.sharedConditions.users.excludeUsers[0] = 'changed-in-result'
        ($plan | ConvertTo-Json -Depth 100 -Compress) | Should -Be $before
    }

    It 'Preserves a rule state of <State>' -ForEach @(
        @{ State = 'enabled' }, @{ State = 'disabled' }, @{ State = 'enabledForReportingButNotEnforced' }
    ) {
        $rule = New-RuleFixture
        $rule.state = $State
        (ConvertTo-MtConditionalAccessPolicy -Plan $script:planFixture -Rule $rule).state | Should -Be $State
    }

    It 'Retains AND/OR and authentication strength requirements without changing their meaning' {
        $rule = New-RuleFixture
        $rule.controls.grantControls.operator = 'AND'
        $rule.controls.grantControls.builtInControls = @('mfa', 'compliantDevice')
        $rule.controls.grantControls.authenticationStrength = [pscustomobject]@{ id = 'strength'; requirementsSatisfied = 'mfa' }
        $policy = ConvertTo-MtConditionalAccessPolicy -Plan $script:planFixture -Rule $rule
        $policy.grantControls.operator | Should -Be AND
        $policy.grantControls.builtInControls | Should -Be @('mfa', 'compliantDevice')
        $policy.grantControls.authenticationStrength.id | Should -Be strength
    }

    It 'Preserves session-only controls' {
        $rule = New-RuleFixture
        $rule.controls.grantControls = $null
        $rule.controls.sessionControls = [pscustomobject]@{ signInFrequency = @{ isEnabled = $true; value = 1; type = 'hours' } }
        $policy = ConvertTo-MtConditionalAccessPolicy -Plan $script:planFixture -Rule $rule
        $policy.sessionControls.signInFrequency.value | Should -Be 1
        $policy.grantControls | Should -BeNullOrEmpty
    }

    It 'Does not put owners into user assignments' {
        $policy = ConvertTo-MtConditionalAccessPolicy -Plan $script:planFixture -Rule $script:ruleFixture[0]
        $policy.planOwners.Count | Should -Be 2
        foreach ($owner in $policy.planOwners) { $policy.conditions.users.includeUsers | Should -Not -Contain $owner }
    }

    It 'Rejects unknown states and missing enforcement controls' {
        $rule = New-RuleFixture
        $rule.state = 'futureState'
        { ConvertTo-MtConditionalAccessPolicy -Plan $script:planFixture -Rule $rule } | Should -Throw '*unsupported state*'
        $rule.state = 'enabled'; $rule.controls = $null
        { ConvertTo-MtConditionalAccessPolicy -Plan $script:planFixture -Rule $rule } | Should -Throw '*enforcement controls*'
    }

    It 'Rejects conflicting filters instead of claiming coverage with an overwritten filter' {
        $plan = New-PlanFixture
        $rule = New-RuleFixture
        $plan.sharedConditions.devices = @{ deviceFilter = @{ mode = 'include'; rule = 'device.isCompliant -eq True' } }
        $rule.conditions.devices = @{ deviceFilter = @{ mode = 'include'; rule = 'device.trustType -eq "AzureAD"' } }
        { ConvertTo-MtConditionalAccessPolicy -Plan $plan -Rule $rule } | Should -Throw '*Cannot safely combine*conditions.devices.deviceFilter.rule*'
    }

    It 'Unions inherited target lists and multi-valued flags' {
        $result = Merge-MtConditionalAccessCondition -Shared @{ users = @{ includeGroups = @('a'); includeGuestsOrExternalUsers = @{ guestOrExternalUserTypes = 'internalGuest' } }; signInRiskLevels = @('high') } -Rule @{ users = @{ includeGroups = @('b', 'a'); includeGuestsOrExternalUsers = @{ guestOrExternalUserTypes = 'b2bCollaborationGuest' } }; signInRiskLevels = @('medium') }
        $result.users.includeGroups | Should -Be @('a', 'b')
        $result.signInRiskLevels | Should -Be @('high', 'medium')
        $result.users.includeGuestsOrExternalUsers.guestOrExternalUserTypes | Should -Be 'internalGuest,b2bCollaborationGuest'
    }

    It 'Rejects a guest-scope union that would introduce type/tenant cross-products' {
        $shared = @{ users = @{ includeGuestsOrExternalUsers = @{ guestOrExternalUserTypes = 'internalGuest'; externalTenants = @{ membershipKind = 'enumerated'; members = @('tenant-a') } } } }
        $rule = @{ users = @{ includeGuestsOrExternalUsers = @{ guestOrExternalUserTypes = 'b2bCollaborationGuest'; externalTenants = @{ membershipKind = 'enumerated'; members = @('tenant-b') } } } }
        { Merge-MtConditionalAccessCondition -Shared $shared -Rule $rule } | Should -Throw '*without broadening*'
    }

    It 'Merges equivalent tenant sets independently of order for <Scope>' -ForEach @(
        @{ Scope = 'includeGuestsOrExternalUsers' }
        @{ Scope = 'excludeGuestsOrExternalUsers' }
    ) {
        $shared = @{ guestOrExternalUserTypes = 'internalGuest'; externalTenants = [ordered]@{ membershipKind = 'enumerated'; members = @('tenant-a', 'tenant-b') } }
        $rule = @{ guestOrExternalUserTypes = 'b2bCollaborationGuest'; externalTenants = [ordered]@{ members = @('TENANT-B', 'tenant-a', 'tenant-a'); membershipKind = 'enumerated' } }
        $beforeShared = $shared | ConvertTo-Json -Depth 100 -Compress
        $beforeRule = $rule | ConvertTo-Json -Depth 100 -Compress
        $result = Merge-MtConditionalAccessCondition -Shared $shared -Rule $rule -PropertyPath "conditions.users.$Scope"
        $result.guestOrExternalUserTypes | Should -Be 'internalGuest,b2bCollaborationGuest'
        $result.externalTenants.members | Should -Be @('tenant-a', 'tenant-b')
        ($shared | ConvertTo-Json -Depth 100 -Compress) | Should -Be $beforeShared
        ($rule | ConvertTo-Json -Depth 100 -Compress) | Should -Be $beforeRule
    }

    It 'Keeps absent, all and enumerated tenant scopes distinct for <Scope>' -ForEach @(
        @{ Scope = 'includeGuestsOrExternalUsers' }
        @{ Scope = 'excludeGuestsOrExternalUsers' }
    ) {
        foreach ($pair in @(
            @{ Shared = $null; Rule = @{ membershipKind = 'all' } }
            @{ Shared = $null; Rule = @{ membershipKind = 'enumerated'; members = @() } }
            @{ Shared = @{ membershipKind = 'all' }; Rule = @{ membershipKind = 'enumerated'; members = @() } }
            @{ Shared = @{ membershipKind = 'enumerated'; members = @('tenant-a') }; Rule = @{ membershipKind = 'enumerated'; members = @() } }
            @{ Shared = @{ membershipKind = 'enumerated'; members = @('tenant-a') }; Rule = @{ membershipKind = 'enumerated'; members = @('tenant-b') } }
        )) {
            $shared = @{ guestOrExternalUserTypes = 'internalGuest'; externalTenants = $pair.Shared }
            $rule = @{ guestOrExternalUserTypes = 'b2bCollaborationGuest'; externalTenants = $pair.Rule }
            { Merge-MtConditionalAccessCondition -Shared $shared -Rule $rule -PropertyPath "conditions.users.$Scope" } | Should -Throw '*without broadening*'
        }
    }

    It 'Merges different guest types when both tenant scopes are all' {
        $shared = @{ guestOrExternalUserTypes = 'internalGuest'; externalTenants = @{ membershipKind = 'all' } }
        $rule = @{ guestOrExternalUserTypes = 'b2bCollaborationGuest'; externalTenants = @{ membershipKind = 'all' } }
        $result = Merge-MtConditionalAccessCondition -Shared $shared -Rule $rule -PropertyPath 'conditions.users.includeGuestsOrExternalUsers'
        $result.externalTenants.membershipKind | Should -Be all
        $result.guestOrExternalUserTypes | Should -Be 'internalGuest,b2bCollaborationGuest'
    }

    It 'Does not mistake Graph response annotations for targeting conflicts' {
        $result = Merge-MtConditionalAccessCondition -Shared @{ '@odata.context' = 'shared'; clientAppTypes = @('all') } -Rule @{ '@odata.context' = 'rule'; clientAppTypes = @('browser') }
        $result.clientAppTypes | Should -Be @('all')
        $result.Contains('@odata.context') | Should -BeFalse
    }

    It 'Preserves the all-external-tenants scope when unioned with selected tenants' {
        $result = Merge-MtConditionalAccessCondition -Shared @{ users = @{ excludeGuestsOrExternalUsers = @{ externalTenants = @{ membershipKind = 'all' } } } } -Rule @{ users = @{ excludeGuestsOrExternalUsers = @{ externalTenants = @{ membershipKind = 'enumerated'; members = @('tenant') } } } }
        $result.users.excludeGuestsOrExternalUsers.externalTenants.membershipKind | Should -Be all
    }
}

Describe 'Plans participate in an existing native CA check' {
    BeforeEach {
        Mock Add-MtTestResultDetail -ModuleName Maester {}
        Mock Invoke-MtGraphRequest -ModuleName Maester { @() } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/policies' }
        Mock Invoke-MtGraphRequest -ModuleName Maester { $script:planFixture } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        $script:testRule = New-RuleFixture
        Mock Invoke-MtGraphRequest -ModuleName Maester { $script:testRule } -ParameterFilter { $RelativeUri -like 'identity/conditionalAccess/plans/*/rules' }
    }

    It 'Recognizes enabled device-compliance enforcement supplied only by a plan' {
        $script:testRule.state = 'enabled'
        Test-MtCaDeviceComplianceExists | Should -BeTrue
    }

    It 'Does not count a <State> rule as active protection' -ForEach @(
        @{ State = 'disabled' }, @{ State = 'enabledForReportingButNotEnforced' }
    ) {
        $script:testRule.state = $State
        Test-MtCaDeviceComplianceExists | Should -BeFalse
    }
}

Describe 'Plan inventory transport uses cached paging' {
    BeforeEach {
        InModuleScope Maester { $__MtSession.GraphCache = @{} }
        Mock Get-MgContext -ModuleName Maester { @{ Environment = 'Global'; TenantId = 'plan-test-tenant' } }
        Mock Get-MgEnvironment -ModuleName Maester { @{ GraphEndpoint = 'https://graph.microsoft.com/' } }
        Mock Invoke-MgGraphRequest -ModuleName Maester {
            switch -Wildcard ($Uri.ToString()) {
                '*plans/plan-a/rules' { return [pscustomobject]@{ value = @(@{ id = 'rule-a' }) } }
                '*plans/plan-b/rules' { return [pscustomobject]@{ value = @(@{ id = 'rule-b' }) } }
                '*plans?*skiptoken*' { return [pscustomobject]@{ value = @(@{ id = 'plan-b'; displayName = 'B' }) } }
                '*conditionalAccess/plans*' { return [pscustomobject]@{ value = @(@{ id = 'plan-a'; displayName = 'A' }); '@odata.nextLink' = 'https://graph.microsoft.com/beta/identity/conditionalAccess/plans?$skiptoken=next' } }
                default { throw "Unexpected URI: $Uri" }
            }
        }
    }

    It 'Reads the next page and reuses the completed plans and rules inventories' {
        $first = @(Get-MtConditionalAccessPolicyPlan)
        $second = @(Get-MtConditionalAccessPolicyPlan)
        $first.Count | Should -Be 2
        $second[1].rules[0].id | Should -Be rule-b
        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 4 -Exactly
    }
}

Describe 'Plan rule reporting through the actual device-compliance check' {
    BeforeEach {
        Mock Invoke-MtGraphRequest -ModuleName Maester { throw "Unexpected endpoint: $RelativeUri" }
        Mock Invoke-MtGraphRequest -ModuleName Maester { @() } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/policies' }
        Mock Invoke-MtGraphRequest -ModuleName Maester { $script:planFixture } -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        $script:reportRules = $script:ruleFixture | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        foreach ($rule in $script:reportRules) {
            $rule.state = 'enabled'
            $rule.controls.grantControls.builtInControls = @('compliantDevice')
        }
        $nonMatchingRule = New-RuleFixture
        $nonMatchingRule.id = '00000000-0000-4000-8000-000000000009'
        $nonMatchingRule.state = 'enabled'
        $nonMatchingRule.controls.grantControls.builtInControls = @('mfa')
        $script:reportRules += $nonMatchingRule
        Mock Invoke-MtGraphRequest -ModuleName Maester { $script:reportRules } -ParameterFilter { $RelativeUri -like 'identity/conditionalAccess/plans/*/rules' }
    }

    It 'Keeps two matching rules from one plan distinct, attributed and linked to their parent' {
        $report = InModuleScope Maester {
            $previousCollection = $__MtSession.IncludeAffectedObjects
            $previousDetails = $__MtSession.TestResultDetail
            $previousTest = [Maester.Engine.MtSession]::EnterTest('MT.1001')
            try {
                $__MtSession.IncludeAffectedObjects = $true
                $__MtSession.TestResultDetail = @{}
                $passed = Test-MtCaDeviceComplianceExists
                $detail = $__MtSession.TestResultDetail['MT.1001']
                $inventory = @(Get-MtAffectedObject -ExcludeSessionCache -MaesterResults ([pscustomobject]@{
                    Tests = @([pscustomobject]@{ Id = 'MT.1001'; ResultDetail = $detail })
                }))
                [pscustomobject]@{ Passed = $passed; Detail = $detail; Inventory = $inventory }
            } finally {
                $__MtSession.IncludeAffectedObjects = $previousCollection
                $__MtSession.TestResultDetail = $previousDetails
                [Maester.Engine.MtSession]::ExitTest($previousTest)
            }
        }

        $report.Passed | Should -BeTrue
        @($report.Detail.RelatedObjects).Count | Should -Be 2
        $report.Detail.RelatedObjects.Id | Sort-Object | Should -Be @($script:ruleFixture.id | Sort-Object)
        $report.Detail.TestResult | Should -Not -Match '%TestResult%|PolicyBlade/policyId|00000000-0000-4000-8000-000000000009'
        $report.Inventory.Count | Should -Be 2
        $report.Inventory.UniqueId | Select-Object -Unique | Should -HaveCount 2
        foreach ($record in $report.Inventory) {
            $record.Type | Should -Be ConditionalAccessPolicyRule
            $record.Tests | Should -Be @('MT.1001')
            $record.Sources | Should -Contain GraphObjects
            $record.PortalLink | Should -BeLike "*PolicyPlanView.ReactView/planId/$($script:planFixture.id)"
        }
    }
}

AfterAll {
    InModuleScope Maester { $__MtSession.AdminPortalUrl = $script:PlanReportingPreviousPortalUrl }
}
