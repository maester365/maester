# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA220", "EXO", "Security", "All" {
    It "ORCA220: Advanced Phishing Threshold Level" {
        $result = Get-ORCA220

        if($null -ne $result) {
            $result | Should -Be $true -Because "Advanced Phish filter Threshold level is adequate."
        }
    }
}
