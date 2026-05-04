Describe 'Test-MtCaExclusionForDirectorySyncAccount' {
    BeforeAll {
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'P1' }
        Mock -ModuleName Maester Add-MtTestResultDetail {}

        # Role template IDs returned by Get-MtRoleInfo
        $script:DirSyncRoleId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
        $script:OnPremRoleId = 'a92aed5d-d78a-4d16-b381-09adb37eb3b0'

        # Sample sync account member IDs
        $script:syncUserId1 = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        $script:syncUserId2 = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
        $script:syncSpId = 'cccccccc-cccc-cccc-cccc-cccccccccccc'

        # Member objects as returned by Get-MtRoleMember
        $script:syncUser1 = [PSCustomObject]@{
            id            = $script:syncUserId1
            '@odata.type' = '#microsoft.graph.user'
        }
        $script:syncUser2 = [PSCustomObject]@{
            id            = $script:syncUserId2
            '@odata.type' = '#microsoft.graph.user'
        }
        $script:syncServicePrincipal = [PSCustomObject]@{
            id            = $script:syncSpId
            '@odata.type' = '#microsoft.graph.servicePrincipal'
        }

        # Helper: build a minimal enabled CA policy object
        function New-CaPolicy {
            param(
                [string]   $Id = 'policy1',
                [string]   $DisplayName = 'Test Policy',
                [string[]] $IncludeApplications = @('All'),
                [string[]] $IncludeUsers = @('All'),
                [string[]] $IncludeRoles = @(),
                [string[]] $ExcludeUsers = @(),
                [string[]] $ExcludeRoles = @(),
                [string]   $IncludeGuestsOrExternalUsers = $null,
                [string[]] $ClientAppTypes = @('all'),
                [string[]] $BuiltInControls = @()
            )
            [PSCustomObject]@{
                id            = $Id
                displayName   = $DisplayName
                state         = 'enabled'
                conditions    = [PSCustomObject]@{
                    applications   = [PSCustomObject]@{
                        includeApplications = $IncludeApplications
                    }
                    users          = [PSCustomObject]@{
                        includeUsers                 = $IncludeUsers
                        includeRoles                 = $IncludeRoles
                        excludeUsers                 = $ExcludeUsers
                        excludeRoles                 = $ExcludeRoles
                        includeGroups                = @()
                        includeGuestsOrExternalUsers = $IncludeGuestsOrExternalUsers
                    }
                    clientAppTypes = $ClientAppTypes
                }
                grantControls = [PSCustomObject]@{
                    builtInControls = $BuiltInControls
                }
            }
        }

        # Default mock: Get-MtRoleInfo returns the correct GUIDs by role name
        Mock -ModuleName Maester Get-MtRoleInfo {
            param($RoleName)
            switch ($RoleName) {
                'DirectorySynchronizationAccounts' { return $script:DirSyncRoleId }
                'OnPremisesDirectorySyncAccount' { return $script:OnPremRoleId }
            }
        }
    }

    Context 'No sync account members exist in the tenant' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $null }
        }

        It 'Should return true and mark test as not applicable' {
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @() }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Service principal-only members (no user members)' {

        BeforeEach {
            # Only a service principal is in the role — no users to exclude
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncServicePrincipal }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -ExcludeUsers @() -ExcludeRoles @())
            }
        }

        It 'Should return true because service principals cannot be excluded from CA policies' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy does not target all applications' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -IncludeApplications @('00000002-0000-0ff1-ce00-000000000000') -ExcludeUsers @() -ExcludeRoles @())
            }
        }

        It 'Should return true because policy is not scoped to all apps' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy only targets guests (no internal users)' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -IncludeUsers @() -IncludeGuestsOrExternalUsers 'b2bCollaborationGuest' -ExcludeUsers @() -ExcludeRoles @())
            }
        }

        It 'Should return true because policy does not scope internal users' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy only blocks legacy authentication' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -ClientAppTypes @('exchangeActiveSync', 'other') -BuiltInControls @('block') -ExcludeUsers @() -ExcludeRoles @())
            }
        }

        It 'Should return true because policy only blocks legacy auth which sync does not use' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy targets all users and sync account is excluded by DirectorySynchronizationAccounts role' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -ExcludeRoles @($script:DirSyncRoleId))
            }
        }

        It 'Should return true' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy targets all users and sync account is excluded by OnPremisesDirectorySyncAccount role' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -ExcludeRoles @($script:OnPremRoleId))
            }
        }

        It 'Should return true' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy targets all users and all sync user members are individually excluded' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return @($script:syncUser1, $script:syncUser2) }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -ExcludeUsers @($script:syncUserId1, $script:syncUserId2))
            }
        }

        It 'Should return true' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy targets all users and sync account is NOT excluded' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -ExcludeUsers @() -ExcludeRoles @())
            }
        }

        It 'Should return false' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }
    }

    Context 'Policy targets all users and sync accounts are only partially excluded by user IDs' {

        BeforeEach {
            # Two user members but only one is excluded
            Mock -ModuleName Maester Get-MtRoleMember { return @($script:syncUser1, $script:syncUser2) }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -ExcludeUsers @($script:syncUserId1))
            }
        }

        It 'Should return false because not all user members are excluded' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }
    }

    Context 'Policy targets all users and sync accounts are only partially excluded (service principal skipped, one user excluded)' {

        BeforeEach {
            # One user + one service principal; only the user is excluded
            Mock -ModuleName Maester Get-MtRoleMember { return @($script:syncUser1, $script:syncServicePrincipal) }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(New-CaPolicy -ExcludeUsers @($script:syncUserId1))
            }
        }

        It 'Should return true because the only user member is excluded and service principals are not subject to CA' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy explicitly includes a sync account by user ID (policy designed for sync accounts)' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                # Policy specifically includes the sync account ID — must not be required to also exclude it
                return @(New-CaPolicy -IncludeUsers @($script:syncUserId1) -ExcludeUsers @() -ExcludeRoles @())
            }
        }

        It 'Should return true because the policy is scoped specifically to the sync account' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Policy explicitly includes a sync role (policy designed for sync accounts)' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                # Policy scoped to the DirectorySynchronizationAccounts role — not an "all users" policy
                return @(New-CaPolicy -IncludeUsers @() -IncludeRoles @($script:DirSyncRoleId) -ExcludeUsers @() -ExcludeRoles @())
            }
        }

        It 'Should return true because the policy is scoped specifically to the sync role' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Multiple policies — one passes, one fails' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                return @(
                    New-CaPolicy -Id 'policy-pass' -DisplayName 'Policy With Exclusion' -ExcludeRoles @($script:DirSyncRoleId),
                    New-CaPolicy -Id 'policy-fail' -DisplayName 'Policy Without Exclusion' -ExcludeUsers @() -ExcludeRoles @()
                )
            }
        }

        It 'Should return false because at least one policy does not exclude sync accounts' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }
    }

    Context 'Multiple policies — all pass (each excluded by a different sync role)' {

        BeforeEach {
            Mock -ModuleName Maester Get-MtRoleMember { return $script:syncUser1 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
                # Hardcode GUIDs to avoid $script: variable resolution inside -ModuleName mock context
                $p1 = New-CaPolicy -Id 'policy1' -DisplayName 'Excluded By DirSync Role' -ExcludeRoles @('d29b2b05-8046-44ba-8758-1e26182fcf32')
                $p2 = New-CaPolicy -Id 'policy2' -DisplayName 'Excluded By OnPrem Role' -ExcludeRoles @('a92aed5d-d78a-4d16-b381-09adb37eb3b0')
                return @($p1, $p2)
            }
        }

        It 'Should return true because all policies exclude sync accounts' {
            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context 'Free Entra ID license' {

        It 'Should return null and skip the test' {
            Mock -ModuleName Maester Get-MtLicenseInformation { return 'Free' }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeNull
        }
    }
}
