Describe "Active Directory - Forest" -Tag "AD", "AD.Forest", "AD-FORS-04" {
    It "AD-FORS-04: Cross-forest references count should be retrievable" {

        $result = Test-MtAdCrossForestReferencesCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "cross-forest reference data should be accessible"
        }
    }
}
