Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-03" {
    It "AD-SPN-03: Computer SPN unknown service class count should be retrievable" {

        $result = Test-MtAdComputerSpnUnknownCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer SPN unknown service class data should be accessible"
        }
    }
}
