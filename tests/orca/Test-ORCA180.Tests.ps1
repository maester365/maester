# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA180", "EXO", "Security", "All" {
    It "ORCA180: Anti-phishing policy exists and EnableSpoofIntelligence is true." {
        $result = Test-ORCA180

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableSpoofIntelligence is true."
        }
    }
}
