Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-02" {
    It "AD-GRP-02: Groups in container objects count should be retrievable" {

        $result = Test-MtAdGroupInContainerCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        }
    }
}
