Describe "CISA" -Tag "MS.EXO", "MS.EXO.17.2", "CISA.MS.EXO.17.2", "CISA" {
    It "CISA.MS.EXO.17.2: Microsoft Purview Audit (Premium) logging SHALL be enabled." -Tag "Deprecated" {

        $result = Test-MtCisaAuditLogPremium

        if ($null -ne $result) {
            $result | Should -Be $true -Because "enabled."
        }
    }
}
