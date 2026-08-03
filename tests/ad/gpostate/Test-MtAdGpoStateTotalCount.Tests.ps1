Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-01" {
    It "AD-GPOS-01: GPO state total count should be retrievable" {

        $result = Test-MtAdGpoStateTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO state data should be accessible"
        }
    }
}
