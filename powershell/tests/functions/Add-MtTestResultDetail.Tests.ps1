Describe 'Add-MtTestResultDetail' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    BeforeEach {
        & (Get-Module Maester) {
            $__MtSession.TestResultDetail = @{}
        }

        Mock -ModuleName Maester Get-MtPesterTagValue { return $null }
    }

    It 'stores details under the active Pester test name when TestName is omitted' {
        Add-MtTestResultDetail -Result 'Captured result detail'

        $resultDetail = & (Get-Module Maester) {
            param($TestName)

            $__MtSession.TestResultDetail[$TestName]
        } $____Pester.CurrentTest.ExpandedName

        $resultDetail.TestTitle | Should -Be $____Pester.CurrentTest.ExpandedName
        $resultDetail.TestResult | Should -Be 'Captured result detail'
    }
}
