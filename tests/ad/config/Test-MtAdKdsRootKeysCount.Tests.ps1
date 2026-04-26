Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-22" {
    It "AD-CFG-22: KDS root keys count should be retrievable" {
        $result = Test-MtAdKdsRootKeysCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "KDS root key data should be accessible"
        }
    }
}
