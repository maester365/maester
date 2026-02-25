Describe "CIS" -Tag "CIS.M365.1.3.4", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.1.3.4: Ensure 'User owned apps and services' is restricted" {

        $result = Test-MtCisUserOwnedAppsRestricted

        if ($null -ne $result) {
            $result | Should -Be $true -Because "'User owned apps and services' is restricted."
        }
    }
}