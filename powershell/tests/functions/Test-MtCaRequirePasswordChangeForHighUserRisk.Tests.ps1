BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'MT.1013 password change for high user risk' {
    BeforeEach {
        InModuleScope Maester {
            $script:passwordPolicy = @{
                id = 'policy-pw'; displayName = 'Password change'; state = 'enabled'
                grantControls = @{ builtInControls = @('passwordChange') }
                conditions = @{
                    users = @{ includeUsers = @('All'); excludeUsers = @(); excludeGroups = @(); excludeRoles = @() }
                    applications = @{ includeApplications = @('All') }
                    userRiskLevels = @('high')
                }
            }
            $script:riskPolicy = @{
                id = 'policy-rr'; displayName = 'Risk remediation'; state = 'enabled'
                grantControls = @{ builtInControls = @('riskRemediation') }
                conditions = @{
                    users = @{ includeUsers = @('All'); excludeUsers = @(); excludeGroups = @(); excludeRoles = @() }
                    applications = @{ includeApplications = @('All') }
                    userRiskLevels = @('high')
                }
            }
            $script:policies = @($script:passwordPolicy)
            Mock Get-MtConditionalAccessPolicy { $script:policies }
            Mock Get-MtEmergencyAccessAccount { @() }
            Mock Add-MtTestResultDetail { }
        }
    }

    It 'Is skipped with a reason that names MT.1253 when a risk remediation policy meets MT.1253' {
        InModuleScope Maester {
            $script:policies = @($script:riskPolicy)
            Test-MtCaRequirePasswordChangeForHighUserRisk | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -like "MT.1253 is met: 'Risk remediation' requires risk remediation*"
            }
        }
    }

    It 'Passes with a password change policy when no risk remediation policy exists' {
        InModuleScope Maester {
            Test-MtCaRequirePasswordChangeForHighUserRisk | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 0 -ParameterFilter { $SkippedBecause }
        }
    }

    It 'Is not skipped when the risk remediation policy does not meet MT.1253 (<Case>)' -ForEach @(
        @{ Case = 'report-only'; Change = { param($p) $p.state = 'enabledForReportingButNotEnforced' } }
        @{ Case = 'user exclusion'; Change = { param($p) $p.conditions.users.excludeUsers = @('11111111-1111-1111-1111-111111111111') } }
        @{ Case = 'medium risk only'; Change = { param($p) $p.conditions.userRiskLevels = @('medium') } }
    ) {
        InModuleScope Maester -Parameters @{ Change = $Change } {
            param($Change)
            & $Change $script:riskPolicy
            $script:policies = @($script:passwordPolicy, $script:riskPolicy)
            Test-MtCaRequirePasswordChangeForHighUserRisk | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 0 -ParameterFilter { $SkippedBecause }
        }
    }

    It 'Fails without a password change policy when the risk remediation policy does not meet MT.1253' {
        InModuleScope Maester {
            $script:riskPolicy.conditions.applications.includeApplications = @('00000002-0000-0ff1-ce00-000000000000')
            $script:policies = @($script:riskPolicy)
            Test-MtCaRequirePasswordChangeForHighUserRisk | Should -BeFalse
        }
    }

    It 'Runs the password change check when the MT.1253 evaluation fails' {
        InModuleScope Maester {
            $script:policies = @($script:passwordPolicy, $script:riskPolicy)
            Mock Get-MtEmergencyAccessAccount { throw 'Emergency access account could not be resolved' }
            Test-MtCaRequirePasswordChangeForHighUserRisk | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 0 -ParameterFilter { $SkippedBecause }
        }
    }
}
