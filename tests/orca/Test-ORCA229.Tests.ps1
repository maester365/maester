# Generated on 03/04/2025 09:34:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA229", "EXO", "Security", "All" {
    It "ORCA229: No trusted domains in Anti-phishing policy." {
        $result = Test-ORCA229

        if($null -ne $result) {
            $result | Should -Be $true -Because "No trusted domains in Anti-phishing policy."
        }
    }
}
