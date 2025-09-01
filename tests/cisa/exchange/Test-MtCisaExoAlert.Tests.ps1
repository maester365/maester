Describe "CISA" -Tag "MS.EXO", "MS.EXO.16.1", "CISA.MS.EXO.16.1", "CISA", "Security" {
    It "CISA.MS.EXO.16.1: Alerts SHALL be enabled." {

        $result = Test-MtCisaExoAlert

        if ($null -ne $result) {
            $result | Should -Be $true -Because "alerts enabled."
        }
    }
}
