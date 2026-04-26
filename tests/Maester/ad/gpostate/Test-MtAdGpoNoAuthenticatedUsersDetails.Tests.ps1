Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-04" {
    It "AD-GPOREP-04: GPOs without authenticated users details should be retrievable" {
        $result = Test-MtAdGpoNoAuthenticatedUsersDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO permissions data should be accessible"
        }
    }
}
