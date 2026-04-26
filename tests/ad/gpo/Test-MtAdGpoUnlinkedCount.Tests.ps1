Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPO-04" {
    It "AD-GPO-04: Unlinked GPO count should be compliant" {

        $result = Test-MtAdGpoUnlinkedCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Unlinked GPOs should not exist"
        }
    }
}
