Describe "CISA" -Tag "MS.EXO", "MS.EXO.15.1", "CISA.MS.EXO.15.1", "CISA", "Security" {
    It "CISA.MS.EXO.15.1: URL comparison with a block-list SHOULD be enabled." {

        $result = Test-MtCisaSafeLink

        if ($null -ne $result) {
            $result | Should -Be $true -Because "safe link enabled."
        }
    }
}
