Describe "CISA" -Tag "MS.EXO", "MS.EXO.5.1", "CISA.MS.EXO.5.1", "CISA", "Security" {
    It "CISA.MS.EXO.5.1: SMTP AUTH SHALL be disabled." {

        $cisaSmtpAuthentication = Test-MtCisaSmtpAuthentication

        if ($null -ne $cisaSmtpAuthentication) {
            $cisaSmtpAuthentication | Should -Be $true -Because "SMTP Authentication is disabled."
        }
    }
}
