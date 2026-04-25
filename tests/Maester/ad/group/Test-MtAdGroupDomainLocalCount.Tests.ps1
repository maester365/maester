Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-08" {
    It "AD-GRP-08: Domain local group count should be retrievable" {

        $result = Test-MtAdGroupDomainLocalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        }
    }
}
