Describe "Active Directory - Forest" -Tag "AD", "AD.Forest", "AD-FORS-03" {
    It "AD-FORS-03: SPN suffixes count should be retrievable" {

        $result = Test-MtAdSpnSuffixesCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "SPN suffix data should be accessible"
        }
    }
}
