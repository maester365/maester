Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-03" {
    It "AD-COMP-03: Computer CreatorSid count should be retrievable" {

        $result = Test-MtAdComputerCreatorSidCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "CreatorSid attribute data should be accessible"
        }
    }
}
