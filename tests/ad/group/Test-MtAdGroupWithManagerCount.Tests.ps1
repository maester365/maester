Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-04" {
    It "AD-GRP-04: Groups with manager count should be retrievable" {

        $result = Test-MtAdGroupWithManagerCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        }
    }
}
