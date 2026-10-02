Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-FEAT-01" {
    It "AD-FEAT-01: Optional feature count should be investigated" {

        $result = Test-MtAdOptionalFeatureCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "optional feature data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
