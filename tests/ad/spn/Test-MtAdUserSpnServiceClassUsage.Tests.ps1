Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-08" {
    It "AD-SPN-08: User SPN service class usage should be investigated" {

        $result = Test-MtAdUserSpnServiceClassUsage

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN service class usage data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
