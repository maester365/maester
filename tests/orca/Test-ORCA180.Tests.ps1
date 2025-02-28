# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA180", "EXO", "Security", "All" {
    It "ORCA180: Anti-spoofing protection" {
        $result = Test-ORCA180

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableSpoofIntelligence is true"
        }
    }
}
