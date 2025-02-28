# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA220", "EXO", "Security", "All" {
    It "ORCA220: Advanced Phishing Threshold Level" {
        $result = Test-ORCA220

        if($null -ne $result) {
            $result | Should -Be $true -Because "Advanced Phish filter Threshold level is adequate."
        }
    }
}
