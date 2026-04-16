Describe 'Test-MtCaExclusionForDirectorySyncAccount' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        Mock -ModuleName Maester Get-MtLicenseInformation { return "P1" }

        # Test IDs
        $script:syncUserId1 = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        $script:syncUserId2 = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        $script:legacyRoleTemplateId = 'd29b2b05-8046-44ba-8758-1e26182fcf32'
        $script:newRoleTemplateId = 'a92aed5d-d78a-4d16-b381-09adb37eb3b0'
        $script:legacyRoleId = '11111111-1111-1111-1111-111111111111'
        $script:newRoleId = '22222222-2222-2222-2222-222222222222'

        function New-MockPolicy {
            param(
                [string]$Id = "policy1",
                [string]$DisplayName = "Test Policy",
                [string[]]$IncludeApplications = @("All"),
                [string[]]$IncludeUsers = @("All"),
                [string[]]$ExcludeUsers = @(),
                [string[]]$ExcludeRoles = @(),
                [string[]]$IncludeRoles = @(),
                [string[]]$IncludeGroups = @(),
                [string[]]$IncludeGuestsOrExternalUsers = @(),
                [string[]]$ClientAppTypes = @("browser", "mobileAppsAndDesktopClients"),
                $GrantControls = @{ builtInControls = @("mfa") }
            )
            return [PSCustomObject]@{
                id             = $Id
                displayName    = $DisplayName
                state          = "enabled"
                conditions     = [PSCustomObject]@{
                    applications = [PSCustomObject]@{
                        includeApplications = $IncludeApplications
                    }
                    users        = [PSCustomObject]@{
                        includeUsers                = $IncludeUsers
                        excludeUsers                = $ExcludeUsers
                        includeGroups               = $IncludeGroups
                        includeRoles                = $IncludeRoles
                        excludeRoles                = $ExcludeRoles
                        includeGuestsOrExternalUsers = $IncludeGuestsOrExternalUsers
                    }
                    clientAppTypes = $ClientAppTypes
                }
                grantControls  = $GrantControls
            }
        }
    }

    Context "No directory sync accounts in tenant" {
        It 'Should return true when no sync roles are found' {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                throw "Role not found"
            }

            $result = Test-MtCaExclusionForDirectorySyncAccount
            $result | Should -BeTrue
        }
    }

    Context "Service principal-only sync configuration" {
        It 'Should return true when all sync members are service principals' {
            $legacyRtId = $legacyRoleTemplateId
            $newRtId = $newRoleTemplateId
            $legacyRId = $legacyRoleId
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    return [PSCustomObject]@{ id = $legacyRId }
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    throw "Role not found"
                }
                if ($RelativeUri -eq "directoryRoles/$legacyRId/members") {
                    return @(
                        [PSCustomObject]@{
                            id            = "sp-id-1"
                            '@odata.type' = '#microsoft.graph.servicePrincipal'
                        }
                    )
                }
            }

            $result = Test-MtCaExclusionForDirectorySyncAccount
            $result | Should -BeTrue
        }
    }

    Context "Legacy role - excludeRoles check" {
        BeforeEach {
            $userId = $syncUserId1
            $legacyRtId = $legacyRoleTemplateId
            $newRtId = $newRoleTemplateId
            $legacyRId = $legacyRoleId
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    return [PSCustomObject]@{ id = $legacyRId }
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    throw "Role not found"
                }
                if ($RelativeUri -eq "directoryRoles/$legacyRId/members") {
                    return @([PSCustomObject]@{ id = $userId; '@odata.type' = '#microsoft.graph.user' })
                }
            }
        }

        It 'Should pass when legacy role is excluded from policy' {
            $policy = New-MockPolicy -ExcludeRoles @($legacyRoleTemplateId)
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should fail when legacy role is NOT excluded from policy' {
            $policy = New-MockPolicy
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }
    }

    Context "New role - excludeRoles check" {
        BeforeEach {
            $userId = $syncUserId1
            $legacyRtId = $legacyRoleTemplateId
            $newRtId = $newRoleTemplateId
            $newRId = $newRoleId
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    throw "Role not found"
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    return [PSCustomObject]@{ id = $newRId }
                }
                if ($RelativeUri -eq "directoryRoles/$newRId/members") {
                    return @(
                        [PSCustomObject]@{ id = $userId; '@odata.type' = '#microsoft.graph.user' }
                    )
                }
            }
        }

        It 'Should pass when new role is excluded from policy' {
            $policy = New-MockPolicy -ExcludeRoles @($newRoleTemplateId)
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should fail when new role is NOT excluded from policy' {
            $policy = New-MockPolicy
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }
    }

    Context "Both roles present" {
        BeforeEach {
            $userId1 = $syncUserId1
            $userId2 = $syncUserId2
            $legacyRtId = $legacyRoleTemplateId
            $newRtId = $newRoleTemplateId
            $legacyRId = $legacyRoleId
            $newRId = $newRoleId
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    return [PSCustomObject]@{ id = $legacyRId }
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    return [PSCustomObject]@{ id = $newRId }
                }
                if ($RelativeUri -eq "directoryRoles/$legacyRId/members") {
                    return @(
                        [PSCustomObject]@{ id = $userId1; '@odata.type' = '#microsoft.graph.user' }
                    )
                }
                if ($RelativeUri -eq "directoryRoles/$newRId/members") {
                    return @(
                        [PSCustomObject]@{ id = $userId2; '@odata.type' = '#microsoft.graph.user' }
                    )
                }
            }
        }

        It 'Should pass when either role is excluded from policy' {
            $policy = New-MockPolicy -ExcludeRoles @($legacyRoleTemplateId)
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Individual user exclusion" {
        BeforeEach {
            $userId = $syncUserId1
            $legacyRtId = $legacyRoleTemplateId
            $newRtId = $newRoleTemplateId
            $legacyRId = $legacyRoleId
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    return [PSCustomObject]@{ id = $legacyRId }
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    throw "Role not found"
                }
                if ($RelativeUri -eq "directoryRoles/$legacyRId/members") {
                    return @([PSCustomObject]@{ id = $userId; '@odata.type' = '#microsoft.graph.user' })
                }
            }
        }

        It 'Should pass when all sync user accounts are individually excluded via excludeUsers' {
            $policy = New-MockPolicy -ExcludeUsers @($syncUserId1)
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should fail when only some sync user accounts are excluded via excludeUsers' {
            $userId1 = $syncUserId1
            $userId2 = $syncUserId2
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    return [PSCustomObject]@{ id = $legacyRId }
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    throw "Role not found"
                }
                if ($RelativeUri -eq "directoryRoles/$legacyRId/members") {
                    return @(
                        [PSCustomObject]@{ id = $userId1; '@odata.type' = '#microsoft.graph.user' },
                        [PSCustomObject]@{ id = $userId2; '@odata.type' = '#microsoft.graph.user' }
                    )
                }
            }
            # Only exclude one of two users
            $policy = New-MockPolicy -ExcludeUsers @($syncUserId1)
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeFalse
        }
    }

    Context "Policy scoping - skip non-applicable policies" {
        BeforeEach {
            $userId = $syncUserId1
            $legacyRtId = $legacyRoleTemplateId
            $newRtId = $newRoleTemplateId
            $legacyRId = $legacyRoleId
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    return [PSCustomObject]@{ id = $legacyRId }
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    throw "Role not found"
                }
                if ($RelativeUri -eq "directoryRoles/$legacyRId/members") {
                    return @([PSCustomObject]@{ id = $userId; '@odata.type' = '#microsoft.graph.user' })
                }
            }
        }

        It 'Should skip policies not scoped to All apps' {
            $policy = New-MockPolicy -IncludeApplications @("specific-app-id")
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should skip policies that block legacy authentication' {
            $policy = New-MockPolicy -ClientAppTypes @("exchangeActiveSync", "other") -GrantControls @{ builtInControls = @("block") }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "includeRoles - sync role directly targeted" {
        BeforeEach {
            $userId = $syncUserId1
            $legacyRtId = $legacyRoleTemplateId
            $newRtId = $newRoleTemplateId
            $legacyRId = $legacyRoleId
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    return [PSCustomObject]@{ id = $legacyRId }
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    throw "Role not found"
                }
                if ($RelativeUri -eq "directoryRoles/$legacyRId/members") {
                    return @([PSCustomObject]@{ id = $userId; '@odata.type' = '#microsoft.graph.user' })
                }
            }
        }

        It 'Should pass when legacy sync role is directly included in policy' {
            $policy = New-MockPolicy -IncludeRoles @($legacyRoleTemplateId)
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }

        It 'Should pass when new sync role is directly included in policy' {
            $policy = New-MockPolicy -IncludeRoles @($newRoleTemplateId)
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Mixed service principal and user members" {
        It 'Should only check user members when mix of SP and user members exist' {
            $userId = $syncUserId1
            $legacyRtId = $legacyRoleTemplateId
            $newRtId = $newRoleTemplateId
            $legacyRId = $legacyRoleId
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri, $Select)
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$legacyRtId')") {
                    return [PSCustomObject]@{ id = $legacyRId }
                }
                if ($RelativeUri -eq "directoryRoles(roleTemplateId='$newRtId')") {
                    throw "Role not found"
                }
                if ($RelativeUri -eq "directoryRoles/$legacyRId/members") {
                    return @(
                        [PSCustomObject]@{ id = $userId; '@odata.type' = '#microsoft.graph.user' },
                        [PSCustomObject]@{ id = "sp-id-1"; '@odata.type' = '#microsoft.graph.servicePrincipal' }
                    )
                }
            }
            # Exclude only the user, not the SP - should still pass since we only check users
            $policy = New-MockPolicy -ExcludeUsers @($syncUserId1)
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($policy) }

            Test-MtCaExclusionForDirectorySyncAccount | Should -BeTrue
        }
    }

    Context "Free license" {
        It 'Should return null when license is Free' {
            Mock -ModuleName Maester Get-MtLicenseInformation { return "Free" }

            $result = Test-MtCaExclusionForDirectorySyncAccount
            $result | Should -BeNullOrEmpty
        }
    }
}
