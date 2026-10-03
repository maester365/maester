Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPO-02" {
    It "AD-GPO-02: GPO created before 2020 count should be retrievable" {

        $result = Test-MtAdGpoCreatedBefore2020Count

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
