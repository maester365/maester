Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-17" {
    It "AD-GPOREP-17: No GPOs should contain a cpassword" {
        $result = Test-MtAdGpoCpasswordFoundCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cpassword values in SYSVOL are recoverable and expose credentials"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
