# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA140", "EXO", "Security", "All" {
    It "ORCA140: High Confidence Spam Action" {
        $result = Get-ORCA140

        if($null -ne $result) {
            $result | Should -Be $true -Because "High Confidence Spam action set to Quarantine message"
        }
    }
}
