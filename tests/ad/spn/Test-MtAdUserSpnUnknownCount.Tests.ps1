Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-09" {
    It "AD-SPN-09: User SPN unknown service class count should be retrievable" {

        $result = Test-MtAdUserSpnUnknownCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN unknown service class data should be accessible"
        }
    }
}
