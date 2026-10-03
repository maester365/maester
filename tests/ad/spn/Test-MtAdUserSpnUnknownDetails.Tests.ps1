Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-10" {
    It "AD-SPN-10: User SPN unknown service class details should be investigated" {

        $result = Test-MtAdUserSpnUnknownDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN unknown service class details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
