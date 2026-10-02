Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-15" {
    It "AD-GPOREP-15: No GPOs should have version mismatches" {
        $result = Test-MtAdGpoVersionMismatchCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "version mismatches may leave security controls unenforced"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
