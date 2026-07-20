Describe "Active Directory - Group Policy Links" -Tag "AD", "AD.GPO", "AD-GPOL-02" {
    It "AD-GPOL-02: Disabled GPO link count should be retrievable" {

        $result = Test-MtAdGpoDisabledLinkCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO link data should be accessible"
        }
    }
}
