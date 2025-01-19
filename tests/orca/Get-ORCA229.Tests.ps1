# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA229", "EXO", "Security", "All" {
    It "ORCA229: Anti-phishing trusted domains" {
        $result = Get-ORCA229

        if($null -ne $result) {
            $result | Should -Be $true -Because "No trusted domains in Anti-phishing policy"
        }
    }
}
