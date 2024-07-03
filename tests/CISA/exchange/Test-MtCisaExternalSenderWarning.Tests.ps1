Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.7.1", "CISA", "Security", "All" {
    It "MS.EXO.7.1: External sender warnings SHALL be implemented." {

        $cisaExternalSenderWarning = Test-MtCisaExternalSenderWarning

        if ($null -ne $cisaExternalSenderWarning) {
            $cisaExternalSenderWarning | Should -Be $true -Because "external sender warning is set."
        }
    }
}