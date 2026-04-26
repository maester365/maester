Describe "Active Directory - Forest" -Tag "AD", "AD.Forest", "AD-FOR-02" {
    It "AD-FOR-02: Forest domain count should be retrievable" {

        $result = Test-MtAdForestDomainCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "forest domain count data should be accessible"
        }
    }
}
