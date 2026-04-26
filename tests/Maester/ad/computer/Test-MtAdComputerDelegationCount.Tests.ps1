Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-09" {
    It "AD-COMP-09: Computer delegation count should be retrievable" {

        $result = Test-MtAdComputerDelegationCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "delegation configuration data should be accessible"
        }
    }
}
