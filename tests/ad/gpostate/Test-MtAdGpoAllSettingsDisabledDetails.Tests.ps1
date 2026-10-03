Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-07" {
    It "AD-GPOS-07: All disabled GPO settings details should be investigated" {

        $result = Test-MtAdGpoAllSettingsDisabledDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "All disabled GPO settings details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
