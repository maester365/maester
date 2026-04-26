Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-12" {
    It "AD-GPOREP-12: GPO disabled link count should be retrievable" {
        $result = Test-MtAdGpoDisabledLinkCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        }
    }
}
