Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-10" {
    It "AD-SPN-10: User SPN unknown service class details should be retrievable" {

        $result = Test-MtAdUserSpnUnknownDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN unknown service class details should be accessible"
        }
    }
}
