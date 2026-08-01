Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-09" {
    It "AD-GPOS-09: GPO owner details should be accessible" {

        $result = Test-MtAdGpoOwnerDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO owner details data should be accessible"
        }
    }
}
