Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-DFSR-01" {
    It "AD-DFSR-01: All domain controllers should have DFS-R subscriptions" {

        $result = Test-MtAdDfsrSubscriptionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "unreplicated SYSVOL may leave DCs with outdated security policies"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
