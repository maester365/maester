# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.104", "EXO", "Security", "All" {
    It "ORCA.104: High Confidence Phish action set to Quarantine message." {
        $result = Test-ORCA104

        if($null -ne $result) {
            $result | Should -Be $true -Because "High Confidence Phish action set to Quarantine message."
        }
    }
}
