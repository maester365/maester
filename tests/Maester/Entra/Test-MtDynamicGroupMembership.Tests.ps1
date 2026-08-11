Describe 'Maester/Entra' -Tag 'Maester', 'Entra' {
    It 'MT.1196: Review dynamic rules. See https://maester.dev/docs/tests/MT.1196' -Tag 'MT.1196' {
        $Result = Test-MtDynamicGroupUserControlledAttributes

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because 'candidate rules should be reported for investigation'
        }
    }

    It 'MT.1197: Remove memberOf rules. See https://maester.dev/docs/tests/MT.1197' -Tag 'MT.1197' {
        $Result = Test-MtDynamicGroupMemberOfRule

        if ($null -ne $Result) {
            $Result | Should -BeTrue -Because 'memberOf groups stop updating after November 3, 2026'
        }
    }
}
