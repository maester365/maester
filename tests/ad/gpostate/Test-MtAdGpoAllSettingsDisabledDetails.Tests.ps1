Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-07" {
    It "AD-GPOS-07: All disabled GPO settings details should be compliant" {

        $result = Test-MtAdGpoAllSettingsDisabledDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "All disabled GPO settings details should be accessible"
        }
    }
}
