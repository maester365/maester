Describe 'Get-GraphObjectMarkdown' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        InModuleScope Maester {
            $script:PlanReportingPreviousPortalUrl = $__MtSession.AdminPortalUrl
            $__MtSession.AdminPortalUrl = @{ Entra = 'https://entra.microsoft.com/' }
        }
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Get-GraphObjectMarkdown
    }

    It 'escapes Markdown in a tenant display name so it cannot break the link or a table row' {
        $policy = [pscustomobject]@{
            id          = '00000000-0000-0000-0000-000000000001'
            displayName = 'Microsoft-managed: A [B] | C'
        }

        $link = Get-GraphObjectMarkdown -GraphObjects $policy -GraphObjectType ConditionalAccess -AsPlainTextLink

        # The colon is escaped now: GFM would otherwise autolink a scheme inside a tenant name.
        # It renders as a plain colon, so the reader sees the name unchanged.
        $link | Should -BeLike '`[Microsoft-managed\: A \`[B\`] \| C`](*PolicyBlade/policyId/00000000-0000-0000-0000-000000000001)'
    }

    It 'keeps a plain display name unchanged in the list form' {
        $policy = [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000002'; displayName = 'Require MFA' }

        Get-GraphObjectMarkdown -GraphObjects $policy -GraphObjectType ConditionalAccess |
            Should -BeLike '  - `[Require MFA`](*PolicyBlade/policyId/00000000-0000-0000-0000-000000000002)*'
    }
    It 'Links a projected plan rule to its parent plan instead of the standalone policy blade' {
        $rule = [pscustomobject]@{ id = 'rule-id'; displayName = 'Plan rule'; planId = 'plan-id'; sourceType = 'PolicyPlanRule' }
        Get-GraphObjectMarkdown -GraphObjects $rule -GraphObjectType ConditionalAccess -AsPlainTextLink |
            Should -BeLike '*PolicyPlanView.ReactView/planId/plan-id)'
    }

    It 'Links owner findings directly to the policy plan' {
        $plan = [pscustomobject]@{ id = 'plan-id'; displayName = 'Plan' }
        Get-GraphObjectMarkdown -GraphObjects $plan -GraphObjectType ConditionalAccessPlan -AsPlainTextLink |
            Should -BeLike '*PolicyPlanView.ReactView/planId/plan-id)'
    }


    It 'Preserves distinct rule identities through a Markdown-only custom table' {
        $objects = InModuleScope Maester {
            $planId = '00000000-0000-4000-8000-000000000001'
            $rules = @(
                [pscustomobject]@{ id = '00000000-0000-4000-8000-000000000007'; displayName = 'Same [name] | rule'; planId = $planId; sourceType = 'PolicyPlanRule' }
                [pscustomobject]@{ id = '00000000-0000-4000-8000-000000000008'; displayName = 'Same [name] | rule'; planId = $planId; sourceType = 'PolicyPlanRule' }
            )
            $markdown = "| Policy | Finding |`n| --- | --- |`n"
            foreach ($rule in $rules) {
                $markdown += "| $(Get-GraphObjectMarkdown -GraphObjects $rule -GraphObjectType ConditionalAccess -AsPlainTextLink) | Review |`n"
            }
            Get-MtAffectedObject -ExcludeSessionCache -MaesterResults ([pscustomobject]@{
                Tests = @([pscustomobject]@{ Id = 'MT.1184'; ResultDetail = @{ TestResult = $markdown } })
            })
        }
        @($objects).Count | Should -Be 2
        $objects.Id | Sort-Object | Should -Be @('00000000-0000-4000-8000-000000000007', '00000000-0000-4000-8000-000000000008')
        foreach ($record in $objects) {
            $record.Type | Should -Be ConditionalAccessPolicyRule
            $record.DisplayName | Should -Be 'Same [name] | rule'
            $record.Tests | Should -Be @('MT.1184')
            $record.PortalLink | Should -BeLike '*PolicyPlanView.ReactView/planId/00000000-0000-4000-8000-000000000001'
        }
    }

    It 'Keeps an ordinary plan link as a plan record' {
        $objects = InModuleScope Maester {
            $plan = [pscustomobject]@{ id = '00000000-0000-4000-8000-000000000001'; displayName = 'Plan' }
            $markdown = Get-GraphObjectMarkdown -GraphObjects $plan -GraphObjectType ConditionalAccessPlan
            Get-MtAffectedObjectFromMarkdown -Markdown $markdown -TestId 'MT.1275'
        }
        @($objects).Count | Should -Be 1
        $objects.Type | Should -Be ConditionalAccessPolicyPlan
        $objects.Id | Should -Be '00000000-0000-4000-8000-000000000001'
    }
}

AfterAll {
    InModuleScope Maester { $__MtSession.AdminPortalUrl = $script:PlanReportingPreviousPortalUrl }
}
