Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-01" {
    It "AD-GPOREP-01: No GPOs should be missing permissions" {
        $result = Test-MtAdGpoNoPermissionsCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "missing GPO permissions prevent intended security policy delivery"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
