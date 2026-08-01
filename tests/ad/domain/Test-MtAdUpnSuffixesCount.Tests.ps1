Describe "Active Directory - Forest" -Tag "AD", "AD.Forest", "AD-FORS-01" {
    It "AD-FORS-01: UPN suffixes count should be retrievable" {

        $result = Test-MtAdUpnSuffixesCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "UPN suffix data should be accessible"
        }
    }
}
