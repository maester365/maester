Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DCD-01" {
    It "AD-DCD-01: DC non-standard LDAP port count should be retrievable" {

        $result = Test-MtAdDcNonStandardLdapPortCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain controller LDAP port configuration data should be accessible"
        }
    }
}
