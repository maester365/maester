Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-10" {
    It "AD-CFG-10: Well-known security principals count should be retrievable" {
        $result = Test-MtAdWellKnownSecurityPrincipalsCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "well-known security principals data should be accessible"
        }
    }
}
