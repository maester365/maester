Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.12.2", "CISA", "Security", "All" {
    It "MS.EXO.12.2: Safe lists SHOULD NOT be enabled." {

        $cisaAntiSpamSafeList = Test-MtCisaAntiSpamSafeList

        if($null -ne $cisaAntiSpamSafeList) {
            $cisaAntiSpamSafeList | Should -Be $true -Because "Safe Lists should be disabled."
        }
    }
}