BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'MT.1253 risk remediation policy coverage' {
    BeforeEach {
        InModuleScope Maester {
            $script:riskPolicy = @{
                id = 'policy-1'; displayName = 'Risk remediation'; state = 'enabled'
                grantControls = @{ builtInControls = @('riskRemediation') }
                conditions = @{
                    users = @{ includeUsers = @('All'); excludeUsers = @(); excludeGroups = @(); excludeRoles = @() }
                    applications = @{ includeApplications = @('All') }
                    userRiskLevels = @('high')
                }
            }
            Mock Get-MtConditionalAccessPolicy { $script:riskPolicy }
            Mock Get-MtEmergencyAccessAccount { @() }
            Mock Invoke-MtGraphRequest { throw 'Unexpected Graph call in offline test' }
            Mock Get-GraphObjectMarkdown { 'Risk remediation policy' }
            Mock Add-MtTestResultDetail { }
        }
    }

    It 'Passes an enabled all-user all-resource high-risk remediation policy' {
        InModuleScope Maester {
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result -like 'Well done.*' }
        }
    }

    It 'Rejects an arbitrary <Field> exclusion even though All users is included' -ForEach @(
        @{ Field = 'excludeUsers' }, @{ Field = 'excludeGroups' }, @{ Field = 'excludeRoles' }
    ) {
        InModuleScope Maester -Parameters @{ Field = $Field } {
            param($Field)
            $script:riskPolicy.conditions.users[$Field] = @('11111111-1111-1111-1111-111111111111')
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result -like '*Only approved user exclusions*' }
        }
    }

    It 'Accepts configured emergency users and dedicated groups together with guest selectors' {
        InModuleScope Maester {
            Mock Get-MtEmergencyAccessAccount {
                @{ ObjectId = 'bg-user'; Type = 'user' }
                @{ ObjectId = 'bg-group'; Type = 'group' }
            }
            $script:riskPolicy.conditions.users.excludeUsers = @('bg-user', 'GuestsOrExternalUsers')
            $script:riskPolicy.conditions.users.excludeGroups = @('bg-group')
            $script:riskPolicy.conditions.users.excludeGuestsOrExternalUsers = @{
                guestOrExternalUserTypes = 'b2bCollaborationGuest,b2bCollaborationMember'
                externalTenants = @{ membershipKind = 'all' }
            }
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeTrue
        }
    }

    It 'Does not let an approved emergency exclusion approve an unrelated workforce group' {
        InModuleScope Maester {
            Mock Get-MtEmergencyAccessAccount { @{ ObjectId = 'bg-user'; Type = 'user' } }
            $script:riskPolicy.conditions.users.excludeUsers = @('bg-user')
            $script:riskPolicy.conditions.users.excludeGroups = @('workforce')
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeFalse
        }
    }

    It 'Does not approve a group using an emergency user entry with the same ID' {
        InModuleScope Maester {
            Mock Get-MtEmergencyAccessAccount { @{ ObjectId = 'same-id'; Type = 'user' } }
            $script:riskPolicy.conditions.users.excludeGroups = @('same-id')
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeFalse
        }
    }

    It 'Accepts a <Type> excluded from every Conditional Access policy when EmergencyAccessAccounts is not set' -ForEach @(
        @{ Type = 'user'; Field = 'excludeUsers' }, @{ Type = 'group'; Field = 'excludeGroups' }
    ) {
        InModuleScope Maester -Parameters @{ Field = $Field } {
            param($Field)
            $script:riskPolicy.conditions.users[$Field] = @('bg-id')
            Mock Get-MtConditionalAccessPolicy {
                $script:riskPolicy
                @{ id = 'policy-2'; displayName = 'MFA'; state = 'enabled'; conditions = @{ users = @{ includeUsers = @('All'); $Field = @('bg-id') } } }
            }
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result -like '*detected automatically*bg-id*' }
        }
    }

    It 'Rejects an exclusion that another Conditional Access policy does not share' {
        InModuleScope Maester {
            $script:riskPolicy.conditions.users.excludeUsers = @('bg-id', 'workforce')
            Mock Get-MtConditionalAccessPolicy {
                $script:riskPolicy
                @{ id = 'policy-2'; displayName = 'MFA'; state = 'enabled'; conditions = @{ users = @{ includeUsers = @('All'); excludeUsers = @('bg-id') } } }
            }
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeFalse
        }
    }

    It 'Does not detect emergency access when EmergencyAccessAccounts is set' {
        InModuleScope Maester {
            Mock Get-MtEmergencyAccessAccount { @{ ObjectId = 'configured'; Type = 'user' } }
            $script:riskPolicy.conditions.users.excludeUsers = @('bg-id')
            Mock Get-MtConditionalAccessPolicy {
                $script:riskPolicy
                @{ id = 'policy-2'; displayName = 'MFA'; state = 'enabled'; conditions = @{ users = @{ includeUsers = @('All'); excludeUsers = @('bg-id') } } }
            }
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeFalse
        }
    }

    It 'Propagates emergency account resolution errors instead of passing' {
        InModuleScope Maester {
            Mock Get-MtEmergencyAccessAccount { throw 'Could not resolve configured emergency access object(s)' }
            { Test-MtCaRequireRiskRemediationForHighUserRisk } | Should -Throw '*Could not resolve*'
        }
    }

    It 'Rejects a policy that is <Condition>' -ForEach @(
        @{ Condition = 'report-only' }, @{ Condition = 'limited to a group' },
        @{ Condition = 'limited to an application' }, @{ Condition = 'missing high risk' },
        @{ Condition = 'password-change only' }
    ) {
        InModuleScope Maester -Parameters @{ Condition = $Condition } {
            param($Condition)
            switch ($Condition) {
                'report-only' { $script:riskPolicy.state = 'enabledForReportingButNotEnforced' }
                'limited to a group' { $script:riskPolicy.conditions.users.includeUsers = @(); $script:riskPolicy.conditions.users.includeGroups = @('group') }
                'limited to an application' { $script:riskPolicy.conditions.applications.includeApplications = @('app') }
                'missing high risk' { $script:riskPolicy.conditions.userRiskLevels = @('medium') }
                'password-change only' { $script:riskPolicy.grantControls.builtInControls = @('passwordChange') }
            }
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeFalse
        }
    }

    It 'Requires all risk levels selected by the parameter' {
        InModuleScope Maester {
            Test-MtCaRequireRiskRemediationForHighUserRisk -MinimumUserRiskLevel medium | Should -BeFalse
            $script:riskPolicy.conditions.userRiskLevels = @('medium', 'high')
            Test-MtCaRequireRiskRemediationForHighUserRisk -MinimumUserRiskLevel medium | Should -BeTrue
        }
    }

    It 'Passes if a second policy qualifies, without accepting the excluded workforce policy' {
        InModuleScope Maester {
            Mock Get-MtConditionalAccessPolicy {
                $script:riskPolicy
                $other = $script:riskPolicy.Clone()
                $other.id = 'policy-2'
                $other.conditions = @{
                    users = @{ includeUsers = @('All'); excludeGroups = @('workforce') }
                    applications = @{ includeApplications = @('All') }
                    userRiskLevels = @('high')
                }
                $other
            }
            Test-MtCaRequireRiskRemediationForHighUserRisk | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result -like '*Only approved user exclusions*' }
        }
    }
}
