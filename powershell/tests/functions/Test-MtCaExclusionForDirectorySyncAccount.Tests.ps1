Describe 'Test-MtCaExclusionForDirectorySyncAccount' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        Mock -ModuleName Maester Get-MtLicenseInformation { return "P1" }

        $script:syncRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
        $script:syncRoleId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        $script:syncUserId1 = '11111111-1111-1111-1111-111111111111'
        $script:syncUserId2 = '22222222-2222-2222-2222-222222222222'
    }

    BeforeEach {
        # Default mock: tenant has sync accounts
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri)
            if ($RelativeUri -like "directoryRoles(roleTemplateId=*") {
                return @{ id = $syncRoleId }
            }
            if ($RelativeUri -like "directoryRoles/*/members") {
                return @(
                    @{ id = $syncUserId1 },
                    @{ id = $syncUserId2 }
                )
            }
        }
    }

    Context "Policy not scoped to all cloud apps" {

        It 'Should pass when policy targets specific apps, not all apps' {
            $policy = [PSCustomObject]@{
                id = 'policy-specific-apps'
                displayName = 'Specific Apps Policy'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('00000003-0000-0000-c000-000000000000')
                    }
                    users = @{
                        includeUsers = @('All')
                        excludeUsers = @()
                        includeGroups = @()
                        includeRoles = @()
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Policy only targeting guests" {

        It 'Should pass when policy only applies to external/guest users' {
            $policy = [PSCustomObject]@{
                id = 'policy-guests'
                displayName = 'Guests Only Policy'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = $null
                        excludeUsers = @()
                        includeGroups = $null
                        includeRoles = $null
                        includeGuestsOrExternalUsers = @{ guestOrExternalUserTypes = 'internalGuest,b2bCollaborationGuest' }
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Legacy authentication blocking policy" {

        It 'Should pass when policy blocks legacy auth (exchangeActiveSync + other)' {
            $policy = [PSCustomObject]@{
                id = 'policy-legacy-block'
                displayName = 'Block Legacy Auth'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @('All')
                        excludeUsers = @()
                        includeGroups = @()
                        includeRoles = @()
                        excludeRoles = @()
                    }
                    clientAppTypes = @('exchangeActiveSync', 'other')
                }
                grantControls = @{
                    builtInControls = @('block')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Sync accounts explicitly included" {

        It 'Should pass when sync users are explicitly included by user ID' {
            $policy = [PSCustomObject]@{
                id = 'policy-sync-users'
                displayName = 'Policy Targeting Sync Users'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @($syncUserId1, $syncUserId2)
                        excludeUsers = @()
                        includeGroups = @()
                        includeRoles = @()
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should pass when sync role is explicitly included' {
            $policy = [PSCustomObject]@{
                id = 'policy-sync-role'
                displayName = 'Policy Targeting Sync Role'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @()
                        excludeUsers = @()
                        includeGroups = @()
                        includeRoles = @($syncRoleTemplateId)
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Policy not scoped to All Users (new logic)" {

        It 'Should pass when policy targets specific users, not All Users' {
            $policy = [PSCustomObject]@{
                id = 'policy-specific-users'
                displayName = 'Specific Users Policy'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @('99999999-9999-9999-9999-999999999999')
                        excludeUsers = @()
                        includeGroups = @()
                        includeRoles = @()
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should pass when policy targets specific groups, not All Users' {
            $policy = [PSCustomObject]@{
                id = 'policy-specific-groups'
                displayName = 'Specific Groups Policy'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @()
                        excludeUsers = @()
                        includeGroups = @('55555555-5555-5555-5555-555555555555')
                        includeRoles = @()
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should pass when policy targets specific roles (not sync role), not All Users' {
            $policy = [PSCustomObject]@{
                id = 'policy-specific-roles'
                displayName = 'Specific Roles Policy'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @()
                        excludeUsers = @()
                        includeGroups = @()
                        includeRoles = @('62e90394-69f5-4237-9190-012177145e10')
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Sync accounts excluded via excludeRoles" {

        It 'Should pass when sync role is in excludeRoles' {
            $policy = [PSCustomObject]@{
                id = 'policy-exclude-role'
                displayName = 'All Users Exclude Sync Role'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @('All')
                        excludeUsers = @()
                        includeGroups = @()
                        includeRoles = @()
                        excludeRoles = @($syncRoleTemplateId)
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Sync accounts excluded via excludeUsers (new logic)" {

        It 'Should pass when all sync users are in excludeUsers' {
            $policy = [PSCustomObject]@{
                id = 'policy-exclude-users'
                displayName = 'All Users Exclude Sync Users'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @('All')
                        excludeUsers = @($syncUserId1, $syncUserId2)
                        includeGroups = @()
                        includeRoles = @()
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should fail when only some sync users are in excludeUsers' {
            $policy = [PSCustomObject]@{
                id = 'policy-partial-exclude'
                displayName = 'All Users Partial Exclude'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @('All')
                        excludeUsers = @($syncUserId1)
                        includeGroups = @()
                        includeRoles = @()
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }
    }

    Context "All Users + All Apps without sync exclusion" {

        It 'Should fail when policy targets All Users and All Apps without excluding sync accounts' {
            $policy = [PSCustomObject]@{
                id = 'policy-all-no-exclusion'
                displayName = 'All Users All Apps No Exclusion'
                state = 'enabled'
                conditions = @{
                    applications = @{
                        includeApplications = @('All')
                    }
                    users = @{
                        includeUsers = @('All')
                        excludeUsers = @()
                        includeGroups = @()
                        includeRoles = @()
                        excludeRoles = @()
                    }
                }
                grantControls = @{
                    builtInControls = @('mfa')
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }
    }

    Context "No sync accounts in tenant" {

        It 'Should pass when tenant has no directory synchronization accounts' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri)
                if ($RelativeUri -like "directoryRoles(roleTemplateId=*") {
                    throw 'Role not found'
                }
            }

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @() }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Mixed policies" {

        It 'Should fail when one policy is compliant but another targets All Users without exclusion' {
            $policies = @(
                [PSCustomObject]@{
                    id = 'policy-good'
                    displayName = 'Good Policy'
                    state = 'enabled'
                    conditions = @{
                        applications = @{
                            includeApplications = @('All')
                        }
                        users = @{
                            includeUsers = @('All')
                            excludeUsers = @()
                            includeGroups = @()
                            includeRoles = @()
                            excludeRoles = @($syncRoleTemplateId)
                        }
                    }
                    grantControls = @{
                        builtInControls = @('mfa')
                    }
                },
                [PSCustomObject]@{
                    id = 'policy-bad'
                    displayName = 'Bad Policy'
                    state = 'enabled'
                    conditions = @{
                        applications = @{
                            includeApplications = @('All')
                        }
                        users = @{
                            includeUsers = @('All')
                            excludeUsers = @()
                            includeGroups = @()
                            includeRoles = @()
                            excludeRoles = @()
                        }
                    }
                    grantControls = @{
                        builtInControls = @('mfa')
                    }
                }
            )

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policies }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }

        It 'Should pass when non-All-Users policy lacks exclusion but All-Users policy has it' {
            $policies = @(
                [PSCustomObject]@{
                    id = 'policy-all-users'
                    displayName = 'All Users With Exclusion'
                    state = 'enabled'
                    conditions = @{
                        applications = @{
                            includeApplications = @('All')
                        }
                        users = @{
                            includeUsers = @('All')
                            excludeUsers = @($syncUserId1, $syncUserId2)
                            includeGroups = @()
                            includeRoles = @()
                            excludeRoles = @()
                        }
                    }
                    grantControls = @{
                        builtInControls = @('mfa')
                    }
                },
                [PSCustomObject]@{
                    id = 'policy-specific'
                    displayName = 'Specific Users No Exclusion'
                    state = 'enabled'
                    conditions = @{
                        applications = @{
                            includeApplications = @('All')
                        }
                        users = @{
                            includeUsers = @('99999999-9999-9999-9999-999999999999')
                            excludeUsers = @()
                            includeGroups = @()
                            includeRoles = @()
                            excludeRoles = @()
                        }
                    }
                    grantControls = @{
                        builtInControls = @('mfa')
                    }
                }
            )

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policies }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }
}
