Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-01" {
    It "AD-GRP-01: Group AdminCount should be retrievable" {

        $result = Test-MtAdGroupAdminCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        }
    }
}
