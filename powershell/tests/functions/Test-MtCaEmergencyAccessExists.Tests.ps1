Describe 'Test-MtCaEmergencyAccessExists' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        Mock -ModuleName Maester Get-MtLicenseInformation { return "P1" }

        # Test user and group IDs
        $script:emergencyUserId1 = "11111111-1111-1111-1111-111111111111"
        $script:emergencyUserId2 = "22222222-2222-2222-2222-222222222222"
        $script:emergencyGroupId1 = "33333333-3333-3333-3333-333333333333"
        $script:emergencyGroupId2 = "44444444-4444-4444-4444-444444444444"

        function Get-PolicyWithNoExclusions {
            $policyJson = @"
[
    {
        "id": "policy1",
        "displayName": "Policy Without Exclusions",
        "state": "enabled",
        "conditions": {
            "applications": {
                "includeApplications": ["All"]
            },
            "users": {
                "includeUsers": ["All"],
                "excludeUsers": [],
                "excludeGroups": []
            }
        }
    }
]
"@
            return $policyJson | ConvertFrom-Json
        }

        function Get-PolicyWithUserExclusion {
            param([string[]]$UserIds)
            $excludeUsers = ($UserIds | ForEach-Object { "`"$_`"" }) -join ","
            $policyJson = @"
[
    {
        "id": "policy1",
        "displayName": "Policy With User Exclusion",
        "state": "enabled",
        "conditions": {
            "applications": {
                "includeApplications": ["All"]
            },
            "users": {
                "includeUsers": ["All"],
                "excludeUsers": [$excludeUsers],
                "excludeGroups": []
            }
        }
    }
]
"@
            return $policyJson | ConvertFrom-Json
        }

        function Get-PolicyWithGroupExclusion {
            param([string[]]$GroupIds)
            $excludeGroups = ($GroupIds | ForEach-Object { "`"$_`"" }) -join ","
            $policyJson = @"
[
    {
        "id": "policy1",
        "displayName": "Policy With Group Exclusion",
        "state": "enabled",
        "conditions": {
            "applications": {
                "includeApplications": ["All"]
            },
            "users": {
                "includeUsers": ["All"],
                "excludeUsers": [],
                "excludeGroups": [$excludeGroups]
            }
        }
    }
]
"@
            return $policyJson | ConvertFrom-Json
        }

        function Get-PolicyWithUserAndGroupExclusion {
            param([string[]]$UserIds, [string[]]$GroupIds)
            $excludeUsers = ($UserIds | ForEach-Object { "`"$_`"" }) -join ","
            $excludeGroups = ($GroupIds | ForEach-Object { "`"$_`"" }) -join ","
            $policyJson = @"
[
    {
        "id": "policy1",
        "displayName": "Policy With User and Group Exclusion",
        "state": "enabled",
        "conditions": {
            "applications": {
                "includeApplications": ["All"]
            },
            "users": {
                "includeUsers": ["All"],
                "excludeUsers": [$excludeUsers],
                "excludeGroups": [$excludeGroups]
            }
        }
    }
]
"@
            return $policyJson | ConvertFrom-Json
        }

        function Get-MultiplePoliciesMixedExclusions {
            param([string[]]$UserIds, [string[]]$GroupIds)
            $excludeUsers = ($UserIds | ForEach-Object { "`"$_`"" }) -join ","
            $excludeGroups = ($GroupIds | ForEach-Object { "`"$_`"" }) -join ","
            $policyJson = @"
[
    {
        "id": "policy1",
        "displayName": "Policy 1 - Full Exclusions",
        "state": "enabled",
        "conditions": {
            "applications": {
                "includeApplications": ["All"]
            },
            "users": {
                "includeUsers": ["All"],
                "excludeUsers": [$excludeUsers],
                "excludeGroups": [$excludeGroups]
            }
        }
    },
    {
        "id": "policy2",
        "displayName": "Policy 2 - Missing Exclusions",
        "state": "enabled",
        "conditions": {
            "applications": {
                "includeApplications": ["All"]
            },
            "users": {
                "includeUsers": ["All"],
                "excludeUsers": [],
                "excludeGroups": []
            }
        }
    }
]
"@
            return $policyJson | ConvertFrom-Json
        }

        function Get-PolicyAgentIdentity {
            $policyJson = @"
[
    {
        "id": "policy-agent",
        "displayName": "Block Agent Identities",
        "state": "enabled",
        "conditions": {
            "applications": {
                "includeApplications": ["All"]
            },
            "users": {
                "includeUsers": ["None"],
                "excludeUsers": [],
                "excludeGroups": []
            },
            "clientApplications": {
                "includeServicePrincipals": [],
                "includeAgentIdServicePrincipals": ["All"],
                "excludeServicePrincipals": []
            }
        }
    }
]
"@
            return $policyJson | ConvertFrom-Json
        }

        function Get-PolicyServicePrincipal {
            $policyJson = @"
[
    {
        "id": "policy-sp",
        "displayName": "Block Service Principals",
        "state": "enabled",
        "conditions": {
            "applications": {
                "includeApplications": ["All"]
            },
            "users": {
                "includeUsers": ["None"],
                "excludeUsers": [],
                "excludeGroups": []
            },
            "clientApplications": {
                "includeServicePrincipals": ["All"],
                "includeAgentIdServicePrincipals": [],
                "excludeServicePrincipals": []
            }
        }
    }
]
"@
            return $policyJson | ConvertFrom-Json
        }
    }

    Context "No emergency access config defined (auto-detection mode)" {

        It 'Should pass when a user is excluded from all policies (auto-detected)' {
            $policy = Get-PolicyWithUserExclusion -UserIds @($emergencyUserId1)

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $null }

            Test-MtCaEmergencyAccessExists | Should -BeTrue
        }

        It 'Should pass when a group is excluded from all policies (auto-detected)' {
            $policy = Get-PolicyWithGroupExclusion -GroupIds @($emergencyGroupId1)

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $null }

            Test-MtCaEmergencyAccessExists | Should -BeTrue
        }
    }

    Context "Single user configured as emergency access" {

        BeforeEach {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri)
                if ($RelativeUri -like "users/*") {
                    return @{ id = $emergencyUserId1; displayName = "Emergency User 1" }
                }
            }
        }

        It 'Should pass when configured user is excluded from all policies' {
            $policy = Get-PolicyWithUserExclusion -UserIds @($emergencyUserId1)
            $config = @(@{ Id = $emergencyUserId1; Type = "User" })

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeTrue
        }

        It 'Should fail when configured user is NOT excluded from policy' {
            $policy = Get-PolicyWithNoExclusions
            $config = @(@{ Id = $emergencyUserId1; Type = "User" })

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }

        It 'Should fail when a different user is excluded but not the configured one' {
            $policy = Get-PolicyWithUserExclusion -UserIds @($emergencyUserId2)
            $config = @(@{ Id = $emergencyUserId1; Type = "User" })

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }
    }

    Context "Single group configured as emergency access" {

        BeforeEach {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri)
                if ($RelativeUri -like "groups/*") {
                    return @{ id = $emergencyGroupId1; displayName = "Emergency Group 1" }
                }
            }
        }

        It 'Should pass when configured group is excluded from all policies' {
            $policy = Get-PolicyWithGroupExclusion -GroupIds @($emergencyGroupId1)
            $config = @(@{ Id = $emergencyGroupId1; Type = "Group" })

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeTrue
        }

        It 'Should fail when configured group is NOT excluded from policy' {
            $policy = Get-PolicyWithNoExclusions
            $config = @(@{ Id = $emergencyGroupId1; Type = "Group" })

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }

        It 'Should fail when a different group is excluded but not the configured one' {
            $policy = Get-PolicyWithGroupExclusion -GroupIds @($emergencyGroupId2)
            $config = @(@{ Id = $emergencyGroupId1; Type = "Group" })

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }
    }

    Context "Both user and group configured as emergency access" {

        BeforeEach {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri)
                if ($RelativeUri -like "users/*") {
                    return @{ id = $emergencyUserId1; displayName = "Emergency User 1" }
                }
                if ($RelativeUri -like "groups/*") {
                    return @{ id = $emergencyGroupId1; displayName = "Emergency Group 1" }
                }
            }
        }

        It 'Should pass when both configured user AND group are excluded from all policies' {
            $policy = Get-PolicyWithUserAndGroupExclusion -UserIds @($emergencyUserId1) -GroupIds @($emergencyGroupId1)
            $config = @(
                @{ Id = $emergencyUserId1; Type = "User" },
                @{ Id = $emergencyGroupId1; Type = "Group" }
            )

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeTrue
        }

        It 'Should fail when only the user is excluded but not the group' {
            $policy = Get-PolicyWithUserExclusion -UserIds @($emergencyUserId1)
            $config = @(
                @{ Id = $emergencyUserId1; Type = "User" },
                @{ Id = $emergencyGroupId1; Type = "Group" }
            )

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }

        It 'Should fail when only the group is excluded but not the user' {
            $policy = Get-PolicyWithGroupExclusion -GroupIds @($emergencyGroupId1)
            $config = @(
                @{ Id = $emergencyUserId1; Type = "User" },
                @{ Id = $emergencyGroupId1; Type = "Group" }
            )

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }

        It 'Should fail when neither user nor group is excluded' {
            $policy = Get-PolicyWithNoExclusions
            $config = @(
                @{ Id = $emergencyUserId1; Type = "User" },
                @{ Id = $emergencyGroupId1; Type = "Group" }
            )

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }
    }

    Context "Multiple policies with mixed exclusions" {

        BeforeEach {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri)
                if ($RelativeUri -like "users/*") {
                    return @{ id = $emergencyUserId1; displayName = "Emergency User 1" }
                }
                if ($RelativeUri -like "groups/*") {
                    return @{ id = $emergencyGroupId1; displayName = "Emergency Group 1" }
                }
            }
        }

        It 'Should fail when one policy has exclusions but another does not' {
            $policies = Get-MultiplePoliciesMixedExclusions -UserIds @($emergencyUserId1) -GroupIds @($emergencyGroupId1)
            $config = @(
                @{ Id = $emergencyUserId1; Type = "User" },
                @{ Id = $emergencyGroupId1; Type = "Group" }
            )

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policies }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }
    }

    Context "UPN-based configuration" {

        BeforeEach {
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                param($RelativeUri)
                if ($RelativeUri -like "users/*") {
                    return @{ id = $emergencyUserId1; displayName = "Emergency User 1" }
                }
            }
        }

        It 'Should pass when user configured by UPN is excluded from all policies' {
            $policy = Get-PolicyWithUserExclusion -UserIds @($emergencyUserId1)
            $config = @(@{ UserPrincipalName = "emergency@contoso.com"; Type = "User" })

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $config }

            Test-MtCaEmergencyAccessExists | Should -BeTrue
        }
    }

    Context "Agent Identity and Service Principal policies" {

        It 'Should return false (no emergency access detected) when only an Agent Identity policy exists (which should be ignored)' {
            $policy = Get-PolicyAgentIdentity

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $null }

            # Returns $false because Agent Identity policies don't apply to users and are filtered out
            # When all policies are filtered out, there are no policies to check, so no emergency access is detected
            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }

        It 'Should return false (no emergency access detected) when only a Service Principal policy exists (which should be ignored)' {
            $policy = Get-PolicyServicePrincipal

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policy }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $null }

            # Returns $false because Service Principal policies don't apply to users and are filtered out
            # When all policies are filtered out, there are no policies to check, so no emergency access is detected
            Test-MtCaEmergencyAccessExists | Should -BeFalse
        }

        It 'Should only check user-targeted policies when both Agent Identity and user policies exist' {
            # Get both types of policies
            $agentPolicy = Get-PolicyAgentIdentity
            $userPolicy = Get-PolicyWithUserExclusion -UserIds @($emergencyUserId1)
            $policies = @($agentPolicy[0], $userPolicy[0])

            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policies }
            Mock -ModuleName Maester Get-MtMaesterConfigGlobalSetting { return $null }

            # Should pass because the Agent Identity policy is ignored and the user policy has exclusions
            Test-MtCaEmergencyAccessExists | Should -BeTrue
        }
    }
}
