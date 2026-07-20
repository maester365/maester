Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPO-03" {
    It "AD-GPO-03: GPO stale-before-2020 count should be retrievable" {

        $result = Test-MtAdGpoChangedBefore2020Count

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO data should be accessible"
        }
    }
}
