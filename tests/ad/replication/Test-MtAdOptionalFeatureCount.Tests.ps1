Describe "Active Directory - Replication" -Tag "AD", "AD.Replication", "AD-FEAT-01" {
    It "AD-FEAT-01: Optional feature count should be retrievable" {

        $result = Test-MtAdOptionalFeatureCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "optional feature data should be accessible"
        }
    }
}
