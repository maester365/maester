Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPO-01" {
    It "AD-GPO-01: GPO total count should be retrievable" {

        $result = Test-MtAdGpoTotalCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO data should be accessible"
        }
    }
}
