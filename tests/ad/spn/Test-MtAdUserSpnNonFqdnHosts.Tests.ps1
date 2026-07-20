Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-11" {
    It "AD-SPN-11: User SPN non-FQDN hosts should be retrievable" {

        $result = Test-MtAdUserSpnNonFqdnHosts

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN non-FQDN host data should be accessible"
        }
    }
}
