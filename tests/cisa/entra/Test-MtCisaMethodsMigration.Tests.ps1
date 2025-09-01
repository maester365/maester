Describe "CISA" -Tag "MS.AAD", "MS.AAD.3.4", "CISA.MS.AAD.3.4", "CISA", "Security", "Entra ID P1" {
    It "CISA.MS.AAD.3.4: The Authentication Methods Manage Migration feature SHALL be set to Migration Complete." {
        $result = Test-MtCisaMethodsMigration

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the migration to Authentication Methods is complete."
        }
    }
}
