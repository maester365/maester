# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.140", "EXO", "Security", "All" {
    It "ORCA.140: High Confidence Spam action set to Quarantine message." {
        $result = Test-ORCA140

        if($null -ne $result) {
            $result | Should -Be $true -Because "High Confidence Spam action set to Quarantine message."
        }
    }
}
