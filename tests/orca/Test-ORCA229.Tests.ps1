# Generated on 01/19/2025 05:57:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA229", "EXO", "Security", "All" {
    It "ORCA229: Anti-phishing trusted domains" {
        $result = Test-ORCA229

        if($null -ne $result) {
            $result | Should -Be $true -Because "No trusted domains in Anti-phishing policy"
        }
    }
}
