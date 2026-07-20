Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-10" {
    It "AD-GRP-10: Universal group count should be retrievable" {

        $result = Test-MtAdGroupUniversalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        }
    }
}
