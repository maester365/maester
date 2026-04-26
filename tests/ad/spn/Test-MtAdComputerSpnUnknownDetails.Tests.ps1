Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-04" {
    It "AD-SPN-04: Computer SPN unknown service class details should be retrievable" {

        $result = Test-MtAdComputerSpnUnknownDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer SPN unknown service class details should be accessible"
        }
    }
}
