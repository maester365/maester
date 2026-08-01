Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-04" {
    It "AD-GPOS-04: Disabled GPO settings count should be retrievable" {

        $result = Test-MtAdGpoSettingsDisabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Disabled GPO settings data should be accessible"
        }
    }
}
