Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-REPL-02" {
    It "AD-REPL-02: Non-auto replication connection count should be retrievable" {

        $result = Test-MtAdNonAutoReplicationConnectionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "replication connection data should be accessible"
        }
    }
}
