Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOM-07" {
    It "AD-DOM-07: NetBIOS name standard compliance should be retrievable" {

        $result = Test-MtAdNetbiosNameStandardCompliance

        if ($null -ne $result) {
            $result | Should -Be $true -Because "NetBIOS name compliance data should be accessible"
        }
    }
}
