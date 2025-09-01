Describe "CISA" -Tag "MS.EXO", "MS.EXO.17.2", "CISA.MS.EXO.17.2", "CISA", "Security" {
    It "CISA.MS.EXO.17.2: Deprecated - Microsoft Purview Audit (Premium) logging SHALL be enabled." {

        $result = Test-MtCisaAuditLogPremium

        if ($null -ne $result) {
            $result | Should -Be $true -Because "enabled."
        }
    }
}
