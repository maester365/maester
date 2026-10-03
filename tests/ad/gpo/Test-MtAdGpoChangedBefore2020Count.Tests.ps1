Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPO-03" {
    It "AD-GPO-03: GPO stale-before-2020 count should be investigated" {

        $result = Test-MtAdGpoChangedBefore2020Count

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
