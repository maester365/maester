Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-03" {
    It "AD-GRP-03: Stale groups count should be retrievable" {

        $result = Test-MtAdGroupStaleCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        }
    }
}
