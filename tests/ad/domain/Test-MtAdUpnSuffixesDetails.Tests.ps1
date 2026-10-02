Describe "Active Directory - Forest" -Tag "AD", "AD.Forest", "AD-FORS-02" {
    It "AD-FORS-02: UPN suffixes details should be retrievable" {

        $result = Test-MtAdUpnSuffixesDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "UPN suffix details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
