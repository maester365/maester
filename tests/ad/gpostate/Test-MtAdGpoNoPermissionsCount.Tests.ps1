Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-01" {
    It "AD-GPOREP-01: GPOs without permissions count should be retrievable" {
        $result = Test-MtAdGpoNoPermissionsCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO permissions data should be accessible"
        }
    }
}
