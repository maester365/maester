Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-DFSR-01" {
    It "AD-DFSR-01: DFS-R subscription count should be retrievable" {

        $result = Test-MtAdDfsrSubscriptionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "DFS-R subscription data should be accessible"
        }
    }
}
