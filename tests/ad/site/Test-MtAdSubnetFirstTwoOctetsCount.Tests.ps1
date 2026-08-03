Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-09" {
    It "AD-SUB-09: Distinct first two octets (/16 networks) count should be retrievable" {

        $result = Test-MtAdSubnetFirstTwoOctetsCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "subnet data should be accessible"
        }
    }
}
