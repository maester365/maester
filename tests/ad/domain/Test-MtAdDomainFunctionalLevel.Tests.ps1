Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOM-01" {
    It "AD-DOM-01: Domain functional level should be retrievable" {

        $result = Test-MtAdDomainFunctionalLevel

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain functional level data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
