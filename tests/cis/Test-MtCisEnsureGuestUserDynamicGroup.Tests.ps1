Describe "CIS" -Tag "CIS.M365.5.1.3.1", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.5.1.3.1: Ensure a dynamic group for guest users is created" {

        $result = Test-MtCisEnsureGuestUserDynamicGroup

        if ($null -ne $result) {
            $result | Should -Be $true -Because "a dynamic group for Guest users exists."
        }
    }
}