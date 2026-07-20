Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-REPL-01" {
    It "AD-REPL-01: Disabled replication connection count should be retrievable" {

        $result = Test-MtAdDisabledReplicationConnectionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "replication connection data should be accessible"
        }
    }
}
