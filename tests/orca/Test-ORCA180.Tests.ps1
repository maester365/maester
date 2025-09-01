# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.180", "EXO", "Security" {
    It "ORCA.180: Anti-phishing policy exists and EnableSpoofIntelligence is true." {
        $result = Test-ORCA180

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableSpoofIntelligence is true."
        }
    }
}
