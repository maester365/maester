Describe "Active Directory - Group Changes" -Tag "AD", "AD.Group", "AD.GCHG", "AD-GCHG-01" {
    It "AD-GCHG-01: Average group membership changes per year should be investigated" {

        $result = Test-MtAdGroupChangeAveragePerYear

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group change history data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
