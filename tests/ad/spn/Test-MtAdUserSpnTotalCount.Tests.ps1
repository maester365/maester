Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-06" {
    It "AD-SPN-06: User SPN total count should be investigated" {

        $result = Test-MtAdUserSpnTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN total count data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
