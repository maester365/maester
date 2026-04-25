Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-01" {
    It "AD-SPN-01: Computer SPN service class count should be retrievable" {

        $result = Test-MtAdComputerSpnServiceClassCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer SPN data should be accessible"
        }
    }
}
