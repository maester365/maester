# Generated on 01/18/2025 20:19:55 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA104", "EXO", "Security", "All" {
    It "ORCA104: High Confidence Phish Action" {
        $result = Test-ORCA104

        if($null -ne $result) {
            $result | Should -Be $true -Because "High Confidence Phish action set to Quarantine message"
        }
    }
}
