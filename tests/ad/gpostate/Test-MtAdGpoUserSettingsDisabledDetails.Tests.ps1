Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-06" {
    It "AD-GPOS-06: User disabled GPO settings details should be compliant" {

        $result = Test-MtAdGpoUserSettingsDisabledDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "User disabled GPO settings details should be accessible"
        }
    }
}
