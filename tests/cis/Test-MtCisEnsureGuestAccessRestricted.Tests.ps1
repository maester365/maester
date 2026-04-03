Describe "CIS" -Tag "CIS.M365.5.1.6.2", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.5.1.6.2: Ensure that guest user access is restricted" {

        $result = Test-MtCisEnsureGuestAccessRestricted

        if ($null -ne $result) {
            $result | Should -Be $true -Because "guest user access is restricted."
        }
    }
}