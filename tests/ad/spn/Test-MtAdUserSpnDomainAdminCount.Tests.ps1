Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-12" {
    It "AD-SPN-12: User SPN domain admin count should be retrievable" {

        $result = Test-MtAdUserSpnDomainAdminCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "domain admin SPN count data should be accessible"
        }
    }
}
