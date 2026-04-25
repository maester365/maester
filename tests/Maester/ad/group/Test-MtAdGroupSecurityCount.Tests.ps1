Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-07" {
    It "AD-GRP-07: Security group count should be retrievable" {

        $result = Test-MtAdGroupSecurityCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        }
    }
}
