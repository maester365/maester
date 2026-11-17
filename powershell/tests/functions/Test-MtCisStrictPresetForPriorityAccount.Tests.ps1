BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisStrictPresetForPriorityAccount

    function Get-StrictRuleFixture {
        param([hashtable] $Conditions = @{})
        $rule = [ordered]@{
            Identity                  = 'Strict Preset Security Policy'
            State                     = 'Enabled'
            SentTo                    = $null
            SentToMemberOf            = $null
            RecipientDomainIs         = $null
        }
        foreach ($key in $Conditions.Keys) { $rule[$key] = $Conditions[$key] }
        [pscustomobject]$rule
    }
}

Describe 'Test-MtCisStrictPresetForPriorityAccount' {
    BeforeEach {
        $script:Result = $null
        $script:EopRule = Get-StrictRuleFixture -Conditions @{ SentToMemberOf = @('Priority Accounts') }
        $script:AtpRule = Get-StrictRuleFixture -Conditions @{ SentToMemberOf = @('Priority Accounts') }
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result) $script:Result = $Result }
        Mock -ModuleName Maester Get-MtExo -ParameterFilter { $Request -in 'EOPProtectionPolicyRule', 'ATPProtectionPolicyRule' } {
            if ($Request -eq 'EOPProtectionPolicyRule') { $script:EopRule } else { $script:AtpRule }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'CIS 2.4.2 does not use Graph.' }
    }

    It 'passes when both enabled rules have recipient conditions' {
        Test-MtCisStrictPresetForPriorityAccount | Should -BeTrue
        $script:Result | Should -Match 'SentToMemberOf'
        Should -Invoke Get-MtExo -ModuleName Maester -ParameterFilter { $Request -eq 'EOPProtectionPolicyRule' } -Times 1 -Exactly
        Should -Invoke Get-MtExo -ModuleName Maester -ParameterFilter { $Request -eq 'ATPProtectionPolicyRule' } -Times 1 -Exactly
    }

    It 'accepts a SentTo target' {
        $script:EopRule = Get-StrictRuleFixture -Conditions @{ SentTo = @('user@contoso.com') }

        Test-MtCisStrictPresetForPriorityAccount | Should -BeTrue
    }

    It 'accepts a RecipientDomainIs target' {
        $script:EopRule = Get-StrictRuleFixture -Conditions @{ RecipientDomainIs = @('contoso.com') }

        Test-MtCisStrictPresetForPriorityAccount | Should -BeTrue
    }

    It 'does not check account coverage with Graph' {
        Test-MtCisStrictPresetForPriorityAccount | Should -BeTrue
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 0 -Exactly
    }

    It 'fails when the rule has no recipient conditions' {
        $script:EopRule = Get-StrictRuleFixture
        $script:EopRule.SentToMemberOf = $null
        $script:AtpRule = Get-StrictRuleFixture

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
        $script:Result | Should -Match 'no recipient conditions'
    }

    It 'fails when the EOP rule has no recipient conditions and the ATP rule is targeted' {
        $script:EopRule = Get-StrictRuleFixture

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
    }

    It 'fails when the ATP rule has no recipient conditions and the EOP rule is targeted' {
        $script:AtpRule = Get-StrictRuleFixture

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
    }

    It 'fails when a rule is not returned' {
        $script:EopRule = $null

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
        $script:Result | Should -Match 'Not found'
    }

    It 'fails when a rule is disabled' {
        $script:AtpRule = Get-StrictRuleFixture -Conditions @{ SentToMemberOf = @('Priority Accounts'); State = 'Disabled' }

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
    }
}
