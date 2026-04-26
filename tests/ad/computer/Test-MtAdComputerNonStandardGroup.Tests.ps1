Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-04" {
    It "AD-COMP-04: Computer non-standard primary group count should be retrievable" {

        $result = Test-MtAdComputerNonStandardGroup

        if ($null -ne $result) {
            $result | Should -Be $true -Because "primary group data should be accessible"
        }
    }
}
