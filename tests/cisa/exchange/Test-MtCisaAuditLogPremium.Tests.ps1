Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.17.2", "CISA", "Security", "All" {
    It "MS.EXO.17.2: Microsoft Purview Audit (Premium) logging SHALL be enabled." {

        $result = Test-MtCisaAuditLogPremium

        if ($null -ne $result) {
            $result | Should -Be $true -Because "enabled."
        }
    }
}