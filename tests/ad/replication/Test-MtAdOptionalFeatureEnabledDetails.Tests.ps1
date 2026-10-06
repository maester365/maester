Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-FEAT-02" {
    It "AD-FEAT-02: Optional feature enabled details should be investigated" {

        $result = Test-MtAdOptionalFeatureEnabledDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "optional feature data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
