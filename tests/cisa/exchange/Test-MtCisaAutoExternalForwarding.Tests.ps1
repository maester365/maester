Describe "CISA" -Tag "MS.EXO", "MS.EXO.1.1", "CISA.MS.EXO.1.1", "CISA", "Security" {
    It "CISA.MS.EXO.1.1: Automatic forwarding to external domains SHALL be disabled." {

        $cisaAutoExternalForwarding = Test-MtCisaAutoExternalForwarding

        if($null -ne $cisaAutoExternalForwarding) {
            $cisaAutoExternalForwarding | Should -Be $true -Because "auto forwarding is not enabled for any domains"
        }
    }
}
