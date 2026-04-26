Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPO-05" {
    It "AD-GPO-05: GPO unlinked details should be compliant" {

        $result = Test-MtAdGpoUnlinkedDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Unlinked GPOs should not exist"
        }
    }
}
