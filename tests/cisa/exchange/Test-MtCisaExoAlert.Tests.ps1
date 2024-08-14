Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.16.1", "CISA", "Security", "All" {
    It "MS.EXO.16.1: Alerts SHALL be enabled." {

        $result = Test-MtCisaExoAlert

        if ($null -ne $result) {
            $result | Should -Be $true -Because "alerts enabled."
        }
    }
}