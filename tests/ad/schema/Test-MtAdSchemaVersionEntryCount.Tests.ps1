Describe "Active Directory - Schema" -Tag "AD", "AD.Schema", "AD-SCH-03" {
    It "AD-SCH-03: Schema version entry count should be retrievable" {

        $result = Test-MtAdSchemaVersionEntryCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "schema version entry count should be accessible"
        }
    }
}
