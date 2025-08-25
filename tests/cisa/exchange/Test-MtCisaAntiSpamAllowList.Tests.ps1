Describe "CISA" -Tag "MS.EXO", "MS.EXO.12.1", "CISA.MS.EXO.12.1", "CISA", "Security" {
    It "CISA.MS.EXO.12.1: IP allow lists SHOULD NOT be created." {

        $cisaAntiSpamAllowList = Test-MtCisaAntiSpamAllowList

        if ($null -ne $cisaAntiSpamAllowList) {
            $cisaAntiSpamAllowList | Should -Be $true -Because "no anti-spam policy allow IPs."
        }
    }
}
