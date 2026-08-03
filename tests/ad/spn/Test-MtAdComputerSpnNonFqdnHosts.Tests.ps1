Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-05" {
    It "AD-SPN-05: Computer SPN non-FQDN hosts should be retrievable" {

        $result = Test-MtAdComputerSpnNonFqdnHosts

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer SPN non-FQDN host data should be accessible"
        }
    }
}
