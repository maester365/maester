Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-06" {
    It "AD-GRP-06: Distribution group count should be retrievable" {

        $result = Test-MtAdGroupDistributionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        }
    }
}
