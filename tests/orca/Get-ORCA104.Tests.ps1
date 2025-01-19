# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA104", "EXO", "Security", "All" {
    It "ORCA104: High Confidence Phish Action" {
        $result = Get-ORCA104

        if($null -ne $result) {
            $result | Should -Be $true -Because "High Confidence Phish action set to Quarantine message"
        }
    }
}
