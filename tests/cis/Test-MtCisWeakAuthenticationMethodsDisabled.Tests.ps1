Describe "CIS" -Tag "CIS.M365.5.2.3.5", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.5.2.3.5: Ensure weak authentication methods are disabled" {

        $result = Test-MtCisWeakAuthenticationMethodsDisabled

        if ($null -ne $result) {
            $result | Should -Be $true -Because "weak authentication methods are disabled."
        }
    }
}