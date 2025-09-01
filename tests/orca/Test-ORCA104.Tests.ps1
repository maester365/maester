# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.104", "EXO", "Security" {
    It "ORCA.104: High Confidence Phish action set to Quarantine message." {
        $result = Test-ORCA104

        if($null -ne $result) {
            $result | Should -Be $true -Because "High Confidence Phish action set to Quarantine message."
        }
    }
}
