# Generated on 03/04/2025 09:34:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA104", "EXO", "Security", "All" {
    It "ORCA104: High Confidence Phish action set to Quarantine message." {
        $result = Test-ORCA104

        if($null -ne $result) {
            $result | Should -Be $true -Because "High Confidence Phish action set to Quarantine message."
        }
    }
}
