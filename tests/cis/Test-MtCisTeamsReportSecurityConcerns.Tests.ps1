Describe "CIS" -Tag "CIS.M365.8.6.1", "L1", "CIS E5 Level 1", "CIS E5", "CIS", "CIS M365 v7.0.0" {
    It "CIS.M365.8.6.1: Ensure users can report security concerns in Teams" {

        $result = Test-MtCisTeamsReportSecurityConcerns

        if ($null -ne $result) {
            $result | Should -Be $true -Because "report security concerns in Teams is only to internal destination."
        }
    }
}
