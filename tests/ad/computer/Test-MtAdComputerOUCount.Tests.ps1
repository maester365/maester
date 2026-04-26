Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-07" {
    It "AD-COMP-07: Computer OU count should be retrievable" {

        $result = Test-MtAdComputerOUCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "OU distribution data should be accessible"
        }
    }
}
