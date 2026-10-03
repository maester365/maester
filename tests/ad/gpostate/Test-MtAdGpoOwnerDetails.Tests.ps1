Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-09" {
    It "AD-GPOS-09: GPO owner details should be investigated" {

        $result = Test-MtAdGpoOwnerDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO owner details data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
