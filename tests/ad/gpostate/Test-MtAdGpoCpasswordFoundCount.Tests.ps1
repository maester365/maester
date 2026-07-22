Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-17" {
    It "AD-GPOREP-17: GPO Cpassword found count should be retrievable" {
        $result = Test-MtAdGpoCpasswordFoundCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        }
    }
}
