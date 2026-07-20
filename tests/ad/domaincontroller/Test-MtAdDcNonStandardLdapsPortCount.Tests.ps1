Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DCD-02" {
    It "AD-DCD-02: DC non-standard LDAPS port count should be retrievable" {

        $result = Test-MtAdDcNonStandardLdapsPortCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain controller LDAPS port configuration data should be accessible"
        }
    }
}
