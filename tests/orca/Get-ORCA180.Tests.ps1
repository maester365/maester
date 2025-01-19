# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA180", "EXO", "Security", "All" {
    It "ORCA180: Anti-spoofing protection" {
        $result = Get-ORCA180

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableSpoofIntelligence is true"
        }
    }
}
