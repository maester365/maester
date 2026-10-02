Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-18" {
    It "AD-GPOREP-18: No GPOs should contain a cpassword" {
        $result = Test-MtAdGpoCpasswordFoundDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "cpassword values in SYSVOL are recoverable and expose credentials"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
