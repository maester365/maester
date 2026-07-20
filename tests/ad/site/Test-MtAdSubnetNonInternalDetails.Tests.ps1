Describe "Active Directory - Sites and Subnets" -Tag "AD", "AD.Site", "AD-SUB-07" {
    It "AD-SUB-07: Non-RFC1918 (public IP) subnets details should be retrievable" {

        $result = Test-MtAdSubnetNonInternalDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "subnet data should be accessible"
        }
    }
}
