# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA241", "EXO", "Security", "All" {
    It "ORCA241: First Contact Safety Tip" {
        $result = Get-ORCA241

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableFirstContactSafetyTips is true"
        }
    }
}
