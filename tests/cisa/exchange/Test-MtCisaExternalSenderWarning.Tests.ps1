Describe "CISA" -Tag "MS.EXO", "MS.EXO.7.1", "CISA.MS.EXO.7.1", "CISA", "Security" {
    It "CISA.MS.EXO.7.1: External sender warnings SHALL be implemented." {

        $cisaExternalSenderWarning = Test-MtCisaExternalSenderWarning

        if ($null -ne $cisaExternalSenderWarning) {
            $cisaExternalSenderWarning | Should -Be $true -Because "external sender warning is set."
        }
    }
}
