Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-13" {
    It "AD-GPOREP-13: GPO disabled link details should be retrievable" {
        $result = Test-MtAdGpoDisabledLinkDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        }
    }
}
