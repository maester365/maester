Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-06" {
    It "AD-CFG-06: LDAP query policy count should be retrievable" {
        $result = Test-MtAdLdapQueryPolicyCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "LDAP query policy data should be accessible"
        }
    }
}
