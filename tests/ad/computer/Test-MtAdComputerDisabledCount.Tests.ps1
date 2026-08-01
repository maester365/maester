Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-01" {
    It "AD-COMP-01: Computer disabled count should be retrievable" {

        $result = Test-MtAdComputerDisabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer object data should be accessible"
        }
    }
}
