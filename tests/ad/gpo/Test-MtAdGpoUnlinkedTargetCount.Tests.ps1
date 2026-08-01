Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPOL-03" {
    It "AD-GPOL-03: GPO unlinked target count should be compliant" {

        $result = Test-MtAdGpoUnlinkedTargetCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Targets without any GPO links should not exist"
        }
    }
}
