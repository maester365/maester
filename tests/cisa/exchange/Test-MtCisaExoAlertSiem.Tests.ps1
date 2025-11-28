Describe "CISA" -Tag "MS.EXO", "MS.EXO.16.2", "CISA.MS.EXO.16.2", "CISA", "Security" {
    It "CISA.MS.EXO.16.2: Alerts SHOULD be sent to a monitored address or incorporated into a security information and event management (SIEM) system." {

        $result = Test-MtCisaExoAlertSiem

        if ($null -ne $result) {
            $result | Should -Be $true -Because "alerts enabled."
        }
    }
}
