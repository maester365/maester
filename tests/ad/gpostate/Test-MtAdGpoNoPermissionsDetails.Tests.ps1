Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-02" {
    It "AD-GPOREP-02: GPOs without permissions details should be retrievable" {
        $result = Test-MtAdGpoNoPermissionsDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO permissions data should be accessible"
        }
    }
}
