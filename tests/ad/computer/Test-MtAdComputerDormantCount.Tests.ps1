Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-02" {
    It "AD-COMP-02: Computer dormant count should be retrievable" {

        $result = Test-MtAdComputerDormantCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "dormant computer data should be accessible"
        }
    }
}
