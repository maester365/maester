BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    InModuleScope Maester {
        $script:PlanReportingPreviousPortalUrl = $__MtSession.AdminPortalUrl
        $__MtSession.AdminPortalUrl = @{ Entra = 'https://entra.microsoft.com/' }
    }
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Get-GraphObjectMarkdown, Test-MtCaWhatIfEmergencyAccessNotBlocked
    $script:evaluationFixture = (Get-Content "$PSScriptRoot/../fixtures/conditional-access-plans/requester-windows-resource-a.json" -Raw | ConvertFrom-Json).value
    $script:planFixture = Get-Content "$PSScriptRoot/../fixtures/conditional-access-plans/plan.json" -Raw | ConvertFrom-Json
}

Describe 'Test-MtConditionalAccessWhatIf' -Tag 'Unit' {
    BeforeAll {
        $script:userId = '00000000-0000-0000-0000-0000000000b1'
        $script:appId = '00000002-0000-0ff1-ce00-000000000000'
    }

    BeforeEach {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicyPlan { @() }
    }

    It 'returns only the policies that apply' {
        Mock -ModuleName Maester Invoke-MgGraphRequest {
            [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id = 'p1'; policyApplies = $true }
                    [pscustomobject]@{ id = 'p2'; policyApplies = $false }
                ) }
        }

        $result = Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId

        @($result).id | Should -Be @('p1')
    }

    It 'throws when the evaluation call fails, so a failure is not read as "no policy applies"' {
        Mock -ModuleName Maester Invoke-MgGraphRequest { throw 'Insufficient privileges to complete the operation.' }

        { Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId } |
            Should -Throw '*Insufficient privileges*'
    }
}

Describe 'What If plan-rule reporting' {
    BeforeEach {
        $script:evaluation = $script:evaluationFixture | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        Mock Invoke-MgGraphRequest -ModuleName Maester { [pscustomobject]@{ value = $script:evaluation } } -ParameterFilter { $Method -eq 'POST' }
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { $script:planFixture }
    }

    It 'Enriches the evaluation fixture by rule ID and preserves every original field without mutating the response' {
        $before = $script:evaluation | ConvertTo-Json -Depth 100 -Compress
        $result = @(Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId)
        $result.Count | Should -Be 2
        foreach ($policy in $result) {
            $original = $script:evaluation | Where-Object id -EQ $policy.id
            $policy.sourceType | Should -Be PolicyPlanRule
            $policy.planId | Should -Be $script:planFixture.id
            $policy.planDisplayName | Should -Be $script:planFixture.displayName
            $originalFields = $policy | Select-Object -Property $original.PSObject.Properties.Name
            ($originalFields | ConvertTo-Json -Depth 100 -Compress) | Should -Be ($original | ConvertTo-Json -Depth 100 -Compress)
            Get-GraphObjectMarkdown -GraphObjects $policy -GraphObjectType ConditionalAccess -AsPlainTextLink |
                Should -BeLike "*PolicyPlanView.ReactView/planId/$($script:planFixture.id)*"
        }
        ($script:evaluation | ConvertTo-Json -Depth 100 -Compress) | Should -Be $before
        Should -Invoke Get-MtConditionalAccessPolicyPlan -ModuleName Maester -Times 1 -Exactly -ParameterFilter { -not $DisableCache }
    }

    It 'Does not infer plan membership from names or change standalone evaluation results' {
        $standalone = $script:evaluation[0] | Select-Object *
        $standalone.id = '00000000-0000-4000-8000-000000000099'
        $script:evaluation = @($standalone)
        $before = $standalone | ConvertTo-Json -Depth 100 -Compress
        $result = @(Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId)
        ($result[0] | ConvertTo-Json -Depth 100 -Compress) | Should -Be $before
        $result[0].PSObject.Properties.Name | Should -Not -Contain planId
        Get-GraphObjectMarkdown -GraphObjects $result -GraphObjectType ConditionalAccess -AsPlainTextLink |
            Should -BeLike "*PolicyBlade/policyId/$($standalone.id))"
    }

    It 'Associates identically named rules and plans using their IDs' {
        $secondPlan = $script:planFixture | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        $secondPlan.id = '00000000-0000-4000-8000-000000000010'
        $secondPlan.rules = @($secondPlan.rules[1])
        $firstPlan = $script:planFixture | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        $firstPlan.rules = @($firstPlan.rules[0])
        $script:sameNamePlans = @($firstPlan, $secondPlan)
        foreach ($policy in $script:evaluation) { $policy.displayName = 'Same name' }
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { $script:sameNamePlans }
        $result = @(Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId)
        $result[0].planId | Should -Be $firstPlan.id
        $result[1].planId | Should -Be $secondPlan.id
        $result.displayName | Should -Be @('Same name', 'Same name')
    }

    It 'Preserves a nonapplying rule with AllResults and filters it otherwise' {
        $script:evaluation[1].policyApplies = $false
        $all = @(Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId -AllResults)
        $applied = @(Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId)
        $all.Count | Should -Be 2
        $all[1].policyApplies | Should -BeFalse
        $all[1].planId | Should -Be $script:planFixture.id
        $applied.id | Should -Be @($script:evaluation[0].id)
    }

    It 'Does not read the inventory when no evaluation result applies' {
        foreach ($policy in $script:evaluation) { $policy.policyApplies = $false }
        @(Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId).Count | Should -Be 0
        Should -Not -Invoke Get-MtConditionalAccessPolicyPlan -ModuleName Maester
    }

    It 'Propagates an unreadable inventory instead of rendering plan rules as standalone policies' {
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { throw '403 plans access denied' }
        { Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId } | Should -Throw '*403 plans access denied*'
    }

    It 'Keeps rule identity and plan links through the actual MT.1034 check and affected-object collector' {
        $report = InModuleScope Maester -Parameters @{ UserId = $script:userId } {
            param($UserId)
            $previousCollection = $__MtSession.IncludeAffectedObjects
            $previousDetails = $__MtSession.TestResultDetail
            $previousTest = [Maester.Engine.MtSession]::EnterTest('MT.1034.0')
            try {
                $__MtSession.IncludeAffectedObjects = $true
                $__MtSession.TestResultDetail = @{}
                $passed = Test-MtCaWhatIfEmergencyAccessNotBlocked -Instance ([pscustomobject]@{
                    Data = [pscustomobject]@{ id = $UserId; userPrincipalName = 'emergency@example.com' }
                })
                $detail = $__MtSession.TestResultDetail['MT.1034.0']
                $inventory = @(Get-MtAffectedObject -ExcludeSessionCache -MaesterResults ([pscustomobject]@{
                    Tests = @([pscustomobject]@{ Id = 'MT.1034.0'; ResultDetail = $detail })
                }))
                [pscustomobject]@{ Passed = $passed; Detail = $detail; Inventory = $inventory }
            } finally {
                $__MtSession.IncludeAffectedObjects = $previousCollection
                $__MtSession.TestResultDetail = $previousDetails
                [Maester.Engine.MtSession]::ExitTest($previousTest)
            }
        }
        $report.Passed | Should -BeFalse
        $report.Detail.TestResult | Should -Not -Match 'PolicyBlade/policyId|%TestResult%'
        $report.Inventory.Count | Should -Be 2
        $report.Inventory.Id | Sort-Object | Should -Be @($script:evaluationFixture.id | Sort-Object)
        foreach ($record in $report.Inventory) {
            $record.Type | Should -Be ConditionalAccessPolicyRule
            $record.Tests | Should -Be @('MT.1034.0')
            $record.PortalLink | Should -BeLike "*PolicyPlanView.ReactView/planId/$($script:planFixture.id)"
        }
    }
}

AfterAll {
    InModuleScope Maester { $__MtSession.AdminPortalUrl = $script:PlanReportingPreviousPortalUrl }
}

Describe 'Repeated What If evaluations use the cached plan inventory' {
    BeforeEach {
        InModuleScope Maester {
            $script:WhatIfPreviousGraphCache = $__MtSession.GraphCache
            $__MtSession.GraphCache = @{}
        }
        Mock Get-MgContext -ModuleName Maester { @{ Environment = 'Global'; TenantId = 'plan-test-tenant' } }
        Mock Get-MgEnvironment -ModuleName Maester { @{ GraphEndpoint = 'https://graph.microsoft.com/' } }
        Mock Invoke-MgGraphRequest -ModuleName Maester {
            if ($Method -eq 'POST') { return [pscustomobject]@{ value = $script:evaluationFixture } }
            if ($Uri.ToString() -like '*/rules') { return [pscustomobject]@{ '@odata.context' = 'https://graph.microsoft.com/beta/$metadata#identity/conditionalAccess/plans/rules'; value = $script:planFixture.rules } }
            if ($Uri.ToString() -like '*/plans') { return [pscustomobject]@{ '@odata.context' = 'https://graph.microsoft.com/beta/$metadata#identity/conditionalAccess/plans'; value = @($script:planFixture) } }
            throw "Unexpected URI: $Uri"
        }
    }

    AfterEach {
        InModuleScope Maester { $__MtSession.GraphCache = $script:WhatIfPreviousGraphCache }
    }

    It 'Evaluates each scenario but reads the plan and rules only once' {
        $first = @(Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId)
        $second = @(Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId -DevicePlatform windows)
        $first.Count | Should -Be 2
        $second.Count | Should -Be 2
        $second.planId | Select-Object -Unique | Should -Be $script:planFixture.id
        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 2 -Exactly -ParameterFilter { $Method -eq 'POST' }
        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 2 -Exactly -ParameterFilter { $Method -ne 'POST' }
    }
}
