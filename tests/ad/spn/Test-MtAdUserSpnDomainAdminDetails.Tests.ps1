Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-13" {
    It "AD-SPN-13: User SPN domain admin details should be retrievable" {

        $result = Test-MtAdUserSpnDomainAdminDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain admin SPN details should be accessible"
        }
    }
}
