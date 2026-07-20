Describe "Active Directory - Schema" -Tag "AD", "AD.Schema", "AD-SCH-02" {
    It "AD-SCH-02: Schema modification year details should be retrievable" {

        $result = Test-MtAdSchemaModificationYearDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "schema modification year details should be accessible"
        }
    }
}
