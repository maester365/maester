Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-10" {
    It "AD-COMP-10: Computer delegation details should be retrievable" {

        $result = Test-MtAdComputerDelegationDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "delegation detail data should be accessible"
        }
    }
}
