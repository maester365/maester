Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-REPL-01" {
    It "AD-REPL-01: No replication connections should be disabled" {

        $result = Test-MtAdDisabledReplicationConnectionCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "disabled replication connections can cause security policy gaps"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
