Describe "Active Directory - Schema" -Tag "AD", "AD.Schema", "AD-SCH-04" {
    It "AD-SCH-04: Schema version details should be retrievable" {

        $result = Test-MtAdSchemaVersionDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "schema version details should be accessible"
        }
    }
}
