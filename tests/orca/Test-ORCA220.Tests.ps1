# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.220", "EXO", "Security" {
    It "ORCA.220: Advanced Phish filter Threshold level is adequate." {
        $result = Test-ORCA220

        if($null -ne $result) {
            $result | Should -Be $true -Because "Advanced Phish filter Threshold level is adequate."
        }
    }
}
