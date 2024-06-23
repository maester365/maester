Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.1.1", "CISA", "Security", "All" {
    It "MS.EXO.1.1: Automatic forwarding to external domains SHALL be disabled." {

        $cisaAutoExternalForwarding = Test-MtCisaAutoExternalForwarding

        if($null -ne $cisaAutoExternalForwarding) {
            $cisaAutoExternalForwarding | Should -Be $true -Because "auto forwarding is not enabled for any domains"
        }
    }
}