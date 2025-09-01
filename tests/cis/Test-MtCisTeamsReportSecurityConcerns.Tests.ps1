Describe "CIS" -Tag "Security", "CIS", "CIS M365 v5.0.0" {
    It "CIS.M365.8.6.1: (L1) Ensure users can report security concerns in Teams to internal destination" -Tag "CIS.M365.8.6.1", "CIS E3 Level 1" {

        $result = Test-MtCisTeamsReportSecurityConcerns

        if ($null -ne $result) {
            $result | Should -Be $true -Because "report security concerns in Teams is only to internal destination."
        }
    }
}
