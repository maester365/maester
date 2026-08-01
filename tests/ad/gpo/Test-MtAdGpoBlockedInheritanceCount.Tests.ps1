Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPOL-05" {
    It "AD-GPOL-05: GPO blocked inheritance count should be compliant" {
        $result = Test-MtAdGpoBlockedInheritanceCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Blocked inheritance should not be configured on any OU"
        }
    }
}
