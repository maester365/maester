Describe 'Test-MtCisCustomerLockBox' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\..\Maester.psd1" -Force
        . "$PSScriptRoot\..\helpers\Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisCustomerLockBox
    }

    BeforeEach {
        Mock Add-MtTestResultDetail -ModuleName Maester { }
    }

    It 'Skips when organization configuration returns <Shape>' -ForEach @(
        @{ Shape = 'no output'; Configuration = @() }
        @{ Shape = 'null'; Configuration = $null }
    ) {
        Mock Get-MtExo -ModuleName Maester { $Configuration }

        $actual = @(Test-MtCisCustomerLockBox)

        $actual.Count | Should -Be 1
        $actual[0] | Should -BeNullOrEmpty
        Should -Invoke Get-MtExo -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Request -eq 'OrganizationConfig'
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $SkippedBecause -eq 'NotAuthorized' -and -not $Result
        }
    }

    It 'Reports <Verdict> with a populated table for <Shape>' -ForEach @(
        @{ Shape = 'enabled'; Configuration = [pscustomobject]@{ CustomerLockBoxEnabled = $true }; Expected = $true; Verdict = 'Pass' }
        @{ Shape = 'disabled'; Configuration = [pscustomobject]@{ CustomerLockBoxEnabled = $false }; Expected = $false; Verdict = 'Fail' }
        @{ Shape = 'missing property'; Configuration = [pscustomobject]@{}; Expected = $false; Verdict = 'Fail' }
        @{ Shape = 'null property'; Configuration = [pscustomobject]@{ CustomerLockBoxEnabled = $null }; Expected = $false; Verdict = 'Fail' }
        @{ Shape = 'string True'; Configuration = [pscustomobject]@{ CustomerLockBoxEnabled = 'True' }; Expected = $true; Verdict = 'Pass' }
        @{ Shape = 'string False'; Configuration = [pscustomobject]@{ CustomerLockBoxEnabled = 'False' }; Expected = $false; Verdict = 'Fail' }
    ) {
        Mock Get-MtExo -ModuleName Maester { $Configuration }

        $actual = @(Test-MtCisCustomerLockBox)

        $actual.Count | Should -Be 1
        $actual[0] | Should -BeOfType [bool]
        $actual[0] | Should -Be $Expected
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            -not $SkippedBecause -and
            $Result -match '\| Customer Lockbox \|\r?\n\| --- \|\r?\n' -and
            $Result -match "\| [^\r\n]* $Verdict \|" -and
            $Result -notmatch '%TestResult%' -and
            ($Result.StartsWith('Well done.') -eq $Expected)
        }
    }

    It 'Fails mixed configuration and reports each row from its setting without IDs' {
        Mock Get-MtExo -ModuleName Maester {
            [pscustomobject]@{ CustomerLockBoxEnabled = $true }
            [pscustomobject]@{ CustomerLockBoxEnabled = $false }
        }

        Test-MtCisCustomerLockBox | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -match '\| [^\r\n]* Pass \|\r?\n\| [^\r\n]* Fail \|' -and
            -not $Result.StartsWith('Well done.')
        }
    }
}
