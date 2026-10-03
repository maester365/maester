Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-08" {
    It "AD-DACL-08: DACL ACE distribution per identity should be investigated" {
        $result = Test-MtAdDaclIdentityAceDistribution

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL identity distribution data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
