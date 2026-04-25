Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-06" {
    It "AD-COMP-06: Computer default container count should be retrievable" {

        $result = Test-MtAdComputerInDefaultContainer

        if ($null -ne $result) {
            $result | Should -Be $true -Because "default container data should be accessible"
        }
    }
}
