Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.17.1", "CISA", "Security", "All" {
    It "MS.EXO.17.1: Microsoft Purview Audit (Standard) logging SHALL be enabled." {

        $result = Test-MtCisaAuditLog

        if ($null -ne $result) {
            $result | Should -Be $true -Because "safe link enabled."
        }
    }
}