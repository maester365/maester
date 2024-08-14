Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.15.1", "CISA", "Security", "All" {
    It "MS.EXO.15.1: URL comparison with a block-list SHOULD be enabled." {

        $result = Test-MtCisaSafeLink

        if ($null -ne $result) {
            $result | Should -Be $true -Because "safe link enabled."
        }
    }
}