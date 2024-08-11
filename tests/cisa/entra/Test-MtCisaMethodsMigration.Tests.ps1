Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.4", "CISA", "Security", "All", "Entra ID P1" {
    It "MS.AAD.3.4: The Authentication Methods Manage Migration feature SHALL be set to Migration Complete." {
        $result = Test-MtCisaMethodsMigration

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the migration to Authentication Methods is complete."
        }
    }
}