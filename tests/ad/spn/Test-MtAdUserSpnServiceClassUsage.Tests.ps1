Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-08" {
    It "AD-SPN-08: User SPN service class usage should be retrievable" {

        $result = Test-MtAdUserSpnServiceClassUsage

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN service class usage data should be accessible"
        }
    }
}
