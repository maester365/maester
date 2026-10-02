Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-14" {
    It "AD-GPOREP-14: GPO enforcement count should be investigated" {
        $result = Test-MtAdGpoEnforcementCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
