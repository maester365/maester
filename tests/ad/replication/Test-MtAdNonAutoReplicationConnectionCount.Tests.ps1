Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-REPL-02" {
    It "AD-REPL-02: Non-auto replication connection count should be investigated" {

        $result = Test-MtAdNonAutoReplicationConnectionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "replication connection data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
