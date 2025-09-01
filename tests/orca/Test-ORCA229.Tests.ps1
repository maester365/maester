# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.229", "EXO", "Security" {
    It "ORCA.229: No trusted domains in Anti-phishing policy." {
        $result = Test-ORCA229

        if($null -ne $result) {
            $result | Should -Be $true -Because "No trusted domains in Anti-phishing policy."
        }
    }
}
