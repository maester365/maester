Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-05" {
    It "AD-GPOS-05: Computer disabled GPO settings details should be compliant" {

        $result = Test-MtAdGpoComputerSettingsDisabledDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Computer disabled GPO settings details should be accessible"
        }
    }
}
