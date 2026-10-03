Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-ROOTDSE-01" {
    It "AD-ROOTDSE-01: Supported SASL mechanism count should be investigated" {

        $result = Test-MtAdSupportedSaslMechanismCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Root DSE data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
