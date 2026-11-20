Describe 'Test-MtCaMfaForAllUsers' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\..\Maester.psd1" -Force
        . "$PSScriptRoot\..\helpers\Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtCaMfaForAllUsers

        # An enabled policy that targets all users and all resources.
        function Get-TestCaPolicy {
            param(
                [string] $DisplayName,
                [string[]] $BuiltInControls = @(),
                [string[]] $CustomAuthenticationFactors = @(),
                [string] $StrengthRequirementsSatisfied,
                [switch] $NoGrantControls
            )
            $grantControls = $null
            if (-not $NoGrantControls) {
                $authenticationStrength = $null
                if ($StrengthRequirementsSatisfied) {
                    $authenticationStrength = [pscustomobject]@{ requirementsSatisfied = $StrengthRequirementsSatisfied }
                }
                $grantControls = [pscustomobject]@{
                    operator                    = 'OR'
                    builtInControls             = $BuiltInControls
                    customAuthenticationFactors = $CustomAuthenticationFactors
                    authenticationStrength      = $authenticationStrength
                }
            }
            [pscustomobject]@{
                displayName   = $DisplayName
                state         = 'enabled'
                conditions    = [pscustomobject]@{
                    users        = [pscustomobject]@{ includeUsers = @('All') }
                    applications = [pscustomobject]@{ includeApplications = @('All') }
                }
                grantControls = $grantControls
            }
        }
    }

    BeforeEach {
        Mock Add-MtTestResultDetail -ModuleName Maester { }
    }

    It 'Passes for a policy that requires built-in MFA' {
        $policies = @(Get-TestCaPolicy -DisplayName 'Require MFA' -BuiltInControls 'mfa')
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester { $policies }

        Test-MtCaMfaForAllUsers | Should -BeTrue
    }

    It 'Passes for a policy that requires an authentication strength that satisfies MFA' {
        $policies = @(Get-TestCaPolicy -DisplayName 'Require phishing-resistant MFA' -StrengthRequirementsSatisfied 'mfa')
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester { $policies }

        Test-MtCaMfaForAllUsers | Should -BeTrue
    }

    It 'Fails for a policy that relies on a custom control, and lists the policy' {
        $policies = @(Get-TestCaPolicy -DisplayName 'Legacy MFA provider' -CustomAuthenticationFactors 'ContosoMFA')
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester { $policies }

        Test-MtCaMfaForAllUsers | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like 'No Conditional Access policy requires*' -and
            $Result -like '*custom control*' -and
            $Result -like '*- Legacy MFA provider*'
        }
    }

    It 'Passes for a policy that requires built-in MFA next to a custom control' {
        $policies = @(Get-TestCaPolicy -DisplayName 'MFA or legacy provider' -BuiltInControls 'mfa' -CustomAuthenticationFactors 'ContosoMFA')
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester { $policies }

        Test-MtCaMfaForAllUsers | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -notlike '*custom control*'
        }
    }

    It 'Passes for a policy that requires MFA, and still lists a separate custom control policy' {
        $policies = @(
            Get-TestCaPolicy -DisplayName 'Require MFA' -BuiltInControls 'mfa'
            Get-TestCaPolicy -DisplayName 'Legacy MFA provider' -CustomAuthenticationFactors 'ContosoMFA'
        )
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester { $policies }

        Test-MtCaMfaForAllUsers | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like 'The following Conditional Access policies require*' -and
            $Result -like '*- Legacy MFA provider*'
        }
    }

    It 'Fails for a policy with session controls only' {
        $policies = @(Get-TestCaPolicy -DisplayName 'Sign-in frequency' -NoGrantControls)
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester { $policies }

        Test-MtCaMfaForAllUsers | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -notlike '*custom control*'
        }
    }
}
