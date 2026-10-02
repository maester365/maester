Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOS-03" {
    It "AD-GPOS-03: WMI filter details should be investigated" {

        $result = Test-MtAdGpoWmiFilterDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO WMI filter details should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
