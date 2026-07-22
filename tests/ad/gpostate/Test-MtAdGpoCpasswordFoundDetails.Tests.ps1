Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-18" {
    It "AD-GPOREP-18: GPO Cpassword found details should be retrievable" {
        $result = Test-MtAdGpoCpasswordFoundDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        }
    }
}
