Describe "CIS" -Tag "CIS.M365.1.3.1", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.1.3.1: (L1) Ensure the 'Password expiration policy' is set to 'Set passwords to never expire (recommended)'" {

        $result = Test-MtCisPasswordExpiry

        if ($null -ne $result) {
            $result | Should -Be $true -Because "passwords are not set to expire"
        }
    }
}
