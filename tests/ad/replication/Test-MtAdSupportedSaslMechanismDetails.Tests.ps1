Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-ROOTDSE-02" {
    It "AD-ROOTDSE-02: Supported SASL mechanism details should be investigated" {

        $result = Test-MtAdSupportedSaslMechanismDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Root DSE data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
