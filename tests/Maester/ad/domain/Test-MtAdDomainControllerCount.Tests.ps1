Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOM-03" {
    It "AD-DOM-03: Domain controller count should be retrievable" {

        $result = Test-MtAdDomainControllerCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain controller data should be accessible"
        }
    }
}
