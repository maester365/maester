Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOMS-01" {
    It "AD-DOMS-01: Allowed DNS suffixes count should be retrievable" {

        $result = Test-MtAdAllowedDnsSuffixesCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "allowed DNS suffix data should be accessible"
        }
    }
}
