Describe "Active Directory - SPN Analysis" -Tag "AD", "AD.SPN", "AD-SPN-06" {
    It "AD-SPN-06: User SPN total count should be retrievable" {

        $result = Test-MtAdUserSpnTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "user SPN total count data should be accessible"
        }
    }
}
