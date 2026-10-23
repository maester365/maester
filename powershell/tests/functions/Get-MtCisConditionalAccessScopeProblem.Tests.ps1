Describe 'Get-MtCisConditionalAccessScopeProblem' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Get-MtCisConditionalAccessScopeProblem, Get-MtCisAdministratorRole

        $script:ExcludedUser = '11111111-1111-1111-1111-111111111111'
        $script:OtherGroup = '22222222-2222-2222-2222-222222222222'
        $script:DirSyncRole = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
        $script:OnPremSyncRole = 'a92aed5d-d78a-4d16-b381-09adb37eb3b0'
        $script:GlobalAdminRole = '62e90394-69f5-4237-9190-012177145e10'

        # Builds a policy from nested hashtables and returns the objects that Graph returns.
        function New-TestPolicy {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param([hashtable] $Conditions)
            @{ displayName = 'Test policy'; state = 'enabled'; conditions = $Conditions } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }
    }

    Context 'Users and exclusions' {
        It 'Passes a policy that includes all users and all apps' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 0
        }

        It 'Reports a policy that does not include all users' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('user-1') }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 1
        }

        It 'Does not report a user exclusion' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All'); excludeUsers = @($script:ExcludedUser) }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 0
        }

        It 'Does not report a group exclusion' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All'); excludeGroups = @($script:OtherGroup) }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 0
        }

        It 'Does not report guest or external user exclusions' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All'); excludeGuestsOrExternalUsers = @{ guestOrExternalUserTypes = 'b2bCollaborationGuest' } }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 0
        }

        It 'Accepts a non-empty user scope when the check requires users not equal to None' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('user-1') }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users NotNone) | Should -HaveCount 0
        }

        It 'Reports None when the check requires users not equal to None' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('None') }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users NotNone) | Should -Be 'no users are included'
        }

        It 'Passes the Directory Synchronization Accounts role as an exclusion' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All'); excludeRoles = @($script:DirSyncRole) }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 0
        }

        It 'Passes the On Premises Directory Sync Account role as an exclusion' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All'); excludeRoles = @($script:OnPremSyncRole) }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 0
        }

        It 'Reports an excluded role that is not a synchronization role' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All'); excludeRoles = @($script:GlobalAdminRole) }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 1
        }

        It 'Passes a policy for administrative roles that includes all 15 roles' {
            $roleIds = @(Get-MtCisAdministratorRole | ForEach-Object { $_.Id })
            $policy = New-TestPolicy @{ users = @{ includeRoles = $roleIds }; applications = @{ includeApplications = @('All') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AdministratorRoles) | Should -HaveCount 0
        }

        It 'Names the administrative role that a policy does not include' {
            $roleIds = @(Get-MtCisAdministratorRole | Select-Object -Skip 1 | ForEach-Object { $_.Id })
            $policy = New-TestPolicy @{ users = @{ includeRoles = $roleIds }; applications = @{ includeApplications = @('All') } }
            $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AdministratorRoles)
            $problems | Should -HaveCount 1
            $problems[0] | Should -BeLike '*Application Administrator*'
        }

        It 'Requires explicit administrator roles instead of all users' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All') } }
            $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AdministratorRoles)
            $problems | Should -HaveCount 1
            $problems[0] | Should -BeLike 'administrative roles not included*'
        }
    }

    Context 'Applications' {
        It 'Reports a policy that does not include all apps unless the check targets an app' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('Office365') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 1
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Applications 'Office365') | Should -HaveCount 0
        }

        It 'Does not report excluded applications when all apps are targeted' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All'); excludeApplications = @('00000002-0000-0ff1-ce00-000000000000') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 0
        }

        It 'Reports a targeted application that the policy excludes' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('Office365'); excludeApplications = @('Office365') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Applications 'Office365') | Should -HaveCount 1
        }

        It 'Accepts a user action as the target of the check' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeUserActions = @('urn:user:registersecurityinfo') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Applications 'urn:user:registersecurityinfo') | Should -HaveCount 0
        }
    }

    Context 'Narrowing conditions' {
        It 'Passes platforms that include all platforms' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All') }; platforms = @{ includePlatforms = @('all'); excludePlatforms = @() } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 0
        }

        It 'Reports platforms unless the check targets them' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All') }; platforms = @{ includePlatforms = @('windows'); excludePlatforms = @() } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 1
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -TargetedCondition Platforms) | Should -HaveCount 0
        }

        It 'Reports a location exclusion' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All') }; locations = @{ includeLocations = @('All'); excludeLocations = @('33333333-3333-3333-3333-333333333333') } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 1
        }

        It 'Reports client app types other than all unless the check targets them' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All') }; clientAppTypes = @('browser') }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 1
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -TargetedCondition ClientAppTypes) | Should -HaveCount 0
        }

        It 'Reports a risk condition unless the check is about it' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All') }; userRiskLevels = @('high') }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 1
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -TargetedCondition UserRiskLevels) | Should -HaveCount 0
        }

        It 'Reports a device filter' {
            $policy = New-TestPolicy @{ users = @{ includeUsers = @('All') }; applications = @{ includeApplications = @('All') }; devices = @{ deviceFilter = @{ mode = 'include'; rule = 'device.isCompliant -eq True' } } }
            @(Get-MtCisConditionalAccessScopeProblem -Policy $policy) | Should -HaveCount 1
        }
    }
}
