Describe "CISA" -Tag "MS.EXO", "MS.EXO.12.2", "CISA.MS.EXO.12.2", "CISA", "Security" {
    It "CISA.MS.EXO.12.2: Safe lists SHOULD NOT be enabled." {

        $cisaAntiSpamSafeList = Test-MtCisaAntiSpamSafeList

        if($null -ne $cisaAntiSpamSafeList) {
            $cisaAntiSpamSafeList | Should -Be $true -Because "Safe Lists should be disabled."
        }
    }
}
