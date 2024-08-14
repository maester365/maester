Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.16.2", "CISA", "Security", "All" {
    It "MS.EXO.16.2: Alerts SHOULD be sent to a monitored address or incorporated into a security information and event management (SIEM) system." {

        $result = Test-MtCisaExoAlertSiem

        if ($null -ne $result) {
            $result | Should -Be $true -Because "alerts enabled."
        }
    }
}