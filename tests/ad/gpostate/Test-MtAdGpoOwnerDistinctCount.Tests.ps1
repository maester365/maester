Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-08" {
    It "AD-GPOS-08: GPO owner distinct count should be retrievable" {

        $result = Test-MtAdGpoOwnerDistinctCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO owner distinct count data should be accessible"
        }
    }
}
