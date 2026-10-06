Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-02" {
    It "AD-GPOS-02: WMI filter count should be investigated" {

        $result = Test-MtAdGpoWmiFilterCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO WMI filter count data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
