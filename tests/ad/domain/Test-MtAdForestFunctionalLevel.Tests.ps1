Describe "Active Directory - Forest" -Tag "AD", "AD.Forest", "AD-FOR-01" {
    It "AD-FOR-01: Forest functional level should be retrievable" {

        $result = Test-MtAdForestFunctionalLevel

        if ($null -ne $result) {
            $result | Should -Be $true -Because "forest functional level data should be accessible"
        }
    }
}
