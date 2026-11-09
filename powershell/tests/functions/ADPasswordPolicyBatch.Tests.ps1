BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../../internal/checks/ad/ad/Test-MtAdPasswordPolicyConfiguration.ps1"
    . "$PSScriptRoot/../../internal/checks/ad/ad/Get-MtAdPasswordPolicyUsage.ps1"

    function Get-MockPasswordPolicy {
        param([int] $Length = 15, [int] $Age = 0)
        [pscustomobject]@{
            DistinguishedName = 'CN=Policy,CN=Password Settings Container,DC=example,DC=org'
            Name = 'Policy'; MsDsPasswordSettingsPrecedence = 1; MsDsPsoAppliesTo = @('CN=Group,DC=example,DC=org')
            MinPwdLength = $Length; PwdHistoryLength = 24; MaxPwdAge = [timespan]::FromDays($Age)
            MinPwdAge = [timespan]::Zero; ComplexityEnabled = $false; ReversibleEncryptionEnabled = $false
            LockoutThreshold = 10; LockoutDuration = [timespan]::FromMinutes(15)
            LockoutObservationWindow = [timespan]::FromMinutes(15); PwdProperties = 16
        }
    }
}

Describe 'Native AD password policy outcomes' {
    BeforeEach {
        InModuleScope Maester {
            $script:settingsInstance = [pscustomobject]@{ Data = [pscustomobject]@{ Kind = 'Settings' } }
            $script:usageInstance = [pscustomobject]@{ Data = [pscustomobject]@{ Kind = 'Usage' } }
        }
        $script:policy = Get-MockPasswordPolicy
        $script:state = [pscustomobject]@{
            Domain = $script:policy
            FineGrainedPasswordPolicies = @($script:policy)
            Users = @([pscustomobject]@{
                    Name = 'Alex'; Enabled = $true; PasswordNeverExpires = $false
                    ResultantPasswordPolicyDN = $script:policy.DistinguishedName
                })
        }
        Mock -ModuleName Maester Get-MtADDomainState { $script:state }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'defines exactly two stable family instances with independent severities' {
        $instances = @(InModuleScope Maester { Get-MtAdFineGrainedPolicyAssessmentInstance })
        $instances.Count | Should -Be 2
        $instances[0].Id | Should -Be 'settings'
        $instances[0].Severity | Should -Be 'High'
        $instances[0].Data.Kind | Should -Be 'Settings'
        $instances[1].Id | Should -Be 'usage'
        $instances[1].Severity | Should -Be 'Low'
        $instances[1].Data.Kind | Should -Be 'Usage'
        (Get-MtTest -Id 'AD-FGPP-01').InstanceSource | Should -Be 'Get-MtAdFineGrainedPolicyAssessmentInstance'
    }

    It 'passes a confirmed settings row and fails weak settings only on the High row' {
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:settingsInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
        Should -Invoke Get-MtADDomainState -ModuleName Maester -ParameterFilter { $Categories -notcontains 'Users' }
        $script:policy.MinPwdLength = 8
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:settingsInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeFalse }
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:usageInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
    }

    It 'investigates unconfirmed usage but fails confirmed zero use only on the Low row' {
        $script:state.Users[0].ResultantPasswordPolicyDN = $null
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:usageInstance | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:usageInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeFalse }
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:settingsInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
    }

    It 'errors on unknown resultant policy only in usage, without turning it into a settings failure' {
        $script:state.Users[0].ResultantPasswordPolicyDN = 'CN=Unknown,DC=example,DC=org'
        InModuleScope Maester { { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:usageInstance -PolicyInventoryReadAccessConfirmed $true } | Should -Throw '*absent*' }
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:settingsInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
    }

    It 'investigates zero visible PSOs and fails confirmed absence only on the Low row' {
        $script:state.FineGrainedPasswordPolicies = @()
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:settingsInstance | Should -BeTrue }
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:usageInstance | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:usageInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeFalse }
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:settingsInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'NotApplicable' }
    }

    It 'does not treat an empty enabled-user inventory as proof that a PSO is unused' {
        $script:state.Users = @()
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:usageInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
        InModuleScope Maester { Test-MtAdUserEffectivePasswordExpiration -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate } -Times 2
    }

    It 'evaluates the complete default-domain profile and overrides the minimum length' {
        InModuleScope Maester { Test-MtAdDefaultPasswordPolicySecurity | Should -BeTrue }
        InModuleScope Maester { Test-MtAdDefaultPasswordPolicySecurity -MinimumLength 20 | Should -BeFalse }
    }

    It 'checks effective user expiration and distinguishes current from legacy rotation' {
        InModuleScope Maester { Test-MtAdUserEffectivePasswordExpiration -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
        InModuleScope Maester { Test-MtAdUserEffectivePasswordExpiration -Profile LegacyRotation -PolicyInventoryReadAccessConfirmed $true | Should -BeFalse }
        $script:policy.MaxPwdAge = [timespan]::FromDays(90)
        InModuleScope Maester { Test-MtAdUserEffectivePasswordExpiration -Profile LegacyRotation -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
    }

    It 'uses the renamed profile parameter and preserves the direct-call alias without changing the automatic variable' {
        $script:policy.MaxPwdAge = [timespan]::FromDays(90)
        $script:policy.ComplexityEnabled = $true
        InModuleScope Maester {
            $originalProfile = $PROFILE
            foreach ($command in 'Test-MtAdFineGrainedPasswordPolicySecurity', 'Test-MtAdDefaultPasswordPolicySecurity', 'Test-MtAdUserEffectivePasswordExpiration') {
                $parameters = @{ ConfigurationProfile = 'LegacyRotation' }
                if ($command -ne 'Test-MtAdDefaultPasswordPolicySecurity') { $parameters.PolicyInventoryReadAccessConfirmed = $true }
                & $command @parameters | Should -BeTrue
                $parameters.Remove('ConfigurationProfile')
                $parameters.Profile = 'LegacyRotation'
                & $command @parameters | Should -BeTrue
            }
            $PROFILE | Should -Be $originalProfile
        }
    }

    It 'discovers the canonical profile parameter with unchanged default and allowed values' {
        foreach ($id in 'AD-FGPP-01', 'AD-PWDPOL-01', 'AD-USER-03') {
            $test = Get-MtTest -Id $id
            $parameter = @($test.Parameters | Where-Object Name -EQ 'ConfigurationProfile')
            $parameter.Count | Should -Be 1 -Because $id
            $parameter[0].Default | Should -Be 'CurrentNist'
            $parameter[0].AllowedValues | Should -Be @('CurrentNist', 'LegacyRotation')
            InModuleScope Maester -Parameters @{ Metadata = $test } {
                param($Metadata)
                $binding = ConvertTo-MtTestParameter -Test $Metadata -ConfigValue @{ ConfigurationProfile = 'LegacyRotation' }
                $binding.Error | Should -BeNullOrEmpty
                $binding.Bound.ConfigurationProfile | Should -Be 'LegacyRotation'
            }
        }
    }

    It 'does not assume an unconfirmed empty resultant DN means default domain' {
        $script:state.Users[0].ResultantPasswordPolicyDN = $null
        InModuleScope Maester { Test-MtAdUserEffectivePasswordExpiration | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }
    It 'does not use a per-account never-expire override to satisfy CurrentNist' {
        $script:policy.MaxPwdAge = [timespan]::FromDays(90)
        $script:state.Users[0].PasswordNeverExpires = $true
        InModuleScope Maester { Test-MtAdUserEffectivePasswordExpiration -PolicyInventoryReadAccessConfirmed $true | Should -BeFalse }
    }
    It 'reports current-profile account overrides for investigation when the effective policy is valid' {
        $script:state.Users[0].PasswordNeverExpires = $true
        InModuleScope Maester { Test-MtAdUserEffectivePasswordExpiration -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }
    It 'retains known policy failures when another user has unconfirmed default-policy visibility' {
        $script:policy.MaxPwdAge = [timespan]::FromDays(90)
        $script:state.Users += [pscustomobject]@{ Name = 'Unknown default'; Enabled = $true; PasswordNeverExpires = $false; ResultantPasswordPolicyDN = $null }
        InModuleScope Maester { Test-MtAdUserEffectivePasswordExpiration | Should -BeFalse }
    }

    It 'observes enabled complexity under CurrentNist instead of failing it' {
        $script:policy.ComplexityEnabled = $true
        InModuleScope Maester { Test-MtAdDefaultPasswordPolicySecurity | Should -BeTrue }
        InModuleScope Maester { Test-MtAdFineGrainedPasswordPolicySecurity -Instance $script:settingsInstance -PolicyInventoryReadAccessConfirmed $true | Should -BeTrue }
        (Test-MtAdPasswordPolicyConfiguration -Policy $script:policy).Rows -join ' ' | Should -Match 'ComplexityEnabled.*Observe'
    }
}

Describe 'Normalized AD password-policy batch' {
    It 'assesses current profile without decoding FGPP PwdProperties or requiring composition rules' {
        $result = Test-MtAdPasswordPolicyConfiguration -Policy (Get-MockPasswordPolicy)
        $result.Passed | Should -BeTrue
        ($result.Rows -join ' ') | Should -Match 'Observe'
    }

    It 'assesses explicit legacy defaults independently from current NIST' {
        $result = Test-MtAdPasswordPolicyConfiguration -Policy (Get-MockPasswordPolicy -Length 14 -Age 90) -Profile LegacyRotation
        $result.Passed | Should -BeFalse
        (Test-MtAdPasswordPolicyConfiguration -Policy (Get-MockPasswordPolicy -Length 14 -Age 90) -Profile LegacyRotation -Fields @('MinPwdLength', 'MaxPwdAge')).Passed | Should -BeTrue
    }

    It 'accepts zero lockout duration as manual administrator unlock' {
        $policy = Get-MockPasswordPolicy
        $policy.LockoutDuration = [timespan]::Zero
        (Test-MtAdPasswordPolicyConfiguration -Policy $policy).Passed | Should -BeTrue
    }

    It 'does not turn a missing field into a false or zero' {
        $policy = Get-MockPasswordPolicy
        $policy.ComplexityEnabled = $null
        { Test-MtAdPasswordPolicyConfiguration -Policy $policy } | Should -Throw '*ComplexityEnabled*'
    }

    It 'uses actual computed resultant policy rather than direct targets' {
        $policy = Get-MockPasswordPolicy
        $users = @([pscustomobject]@{ Name = 'Alex'; Enabled = $true; ResultantPasswordPolicyDN = $policy.DistinguishedName })
        (Get-MtAdPasswordPolicyUsage -Users $users -Policies @($policy)).Counts[$policy.DistinguishedName] | Should -Be 1
    }

    It 'rejects missing and unknown resultant policy attributes' {
        $policy = Get-MockPasswordPolicy
        { Get-MtAdPasswordPolicyUsage -Users @([pscustomobject]@{ Name = 'Alex'; Enabled = $true }) -Policies @($policy) } | Should -Throw '*ResultantPasswordPolicyDN*'
        { Get-MtAdPasswordPolicyUsage -Users @([pscustomobject]@{ Name = 'Alex'; Enabled = $true; ResultantPasswordPolicyDN = 'CN=unknown' }) -Policies @($policy) } | Should -Throw '*absent*'
    }
}
