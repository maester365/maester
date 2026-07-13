<#
    Source-tree regression for #1924.

    Ensures Test-MtCisaDlpPii always initializes $result before substituting
    %TestResult%, so empty rule sets cannot pick up parent-scope values.
    The built-module CI gate is build/Test-MaesterResultDetailRegression.ps1.
#>
Describe 'Result detail initialization' -Tag 'General', 'ResultDetail' {
    BeforeAll {
        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'Plan' }
        Mock -ModuleName Maester Get-MtExo { return @() }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            $script:CapturedResultDetail = $Result
        }
    }

    It 'Test-MtCisaDlpPii empty rules produce a clean failure message without function source' {
        $script:CapturedResultDetail = $null

        $outcome = Test-MtCisaDlpPii

        $outcome | Should -BeFalse
        $script:CapturedResultDetail | Should -Not -BeNullOrEmpty
        $script:CapturedResultDetail | Should -Match 'Your tenant does not have.*Data Loss Prevention Policies'
        $script:CapturedResultDetail | Should -Not -Match 'Add-MtTestResultDetail\s+-Description'
        $script:CapturedResultDetail | Should -Not -Match '\.SYNOPSIS'
    }
}
