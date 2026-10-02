Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-06" {
    It "AD-GPOS-06: User disabled GPO settings details should be investigated" {

        $result = Test-MtAdGpoUserSettingsDisabledDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "User disabled GPO settings details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
