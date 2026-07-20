Describe "Active Directory - Schema" -Tag "AD", "AD.Schema", "AD-SCH-01" {
    It "AD-SCH-01: Schema modification year count should be retrievable" {

        $result = Test-MtAdSchemaModificationYearCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "schema modification year data should be accessible"
        }
    }
}
