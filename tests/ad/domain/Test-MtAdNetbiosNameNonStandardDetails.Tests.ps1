Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOM-08" {
    It "AD-DOM-08: NetBIOS name non-standard details should be retrievable" {

        $result = Test-MtAdNetbiosNameNonStandardDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "NetBIOS name non-standard details should be accessible"
        }
    }
}
