Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-07" {
    It "AD-SPN-07: User SPN service class count should be investigated" {

        $result = Test-MtAdUserSpnServiceClassCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN service class count data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
