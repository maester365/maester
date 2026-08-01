Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-09" {
    It "AD-GPOREP-09: GPO inherited permissions count should be retrievable" {
        $result = Test-MtAdGpoInheritedPermissionsCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO permissions data should be accessible"
        }
    }
}
