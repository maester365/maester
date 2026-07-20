Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-ROOTDSE-01" {
    It "AD-ROOTDSE-01: Supported SASL mechanism count should be retrievable" {

        $result = Test-MtAdSupportedSaslMechanismCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Root DSE data should be accessible"
        }
    }
}
