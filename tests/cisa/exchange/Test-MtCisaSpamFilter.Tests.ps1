Describe "CISA" -Tag "MS.EXO", "MS.EXO.14.1", "CISA.MS.EXO.14.1", "CISA", "Security" {
    It "CISA.MS.EXO.14.1: A spam filter SHALL be enabled." {

        $result = Test-MtCisaSpamFilter

        if ($null -ne $result) {
            $result | Should -Be $true -Because "spam filter enabled."
        }
    }
}
