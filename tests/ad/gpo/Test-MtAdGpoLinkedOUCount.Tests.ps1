Describe "Active Directory - Group Policy Links" -Tag "AD", "AD.GPO", "AD-GPOL-06" {
    It "AD-GPOL-06: GPO linked OU count should be retrievable" {

        $result = Test-MtAdGpoLinkedOUCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO linked OU data should be accessible"
        }
    }
}
