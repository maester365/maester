Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-10" {
    It "AD-SUB-10: Distinct first three octets (/24 networks) count should be retrievable" {

        $result = Test-MtAdSubnetFirstThreeOctetsCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "subnet data should be accessible"
        }
    }
}
