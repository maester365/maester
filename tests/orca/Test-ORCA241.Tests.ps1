# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA241", "EXO", "Security", "All" {
    It "ORCA241: Anti-phishing policy exists and EnableFirstContactSafetyTips is true." {
        $result = Test-ORCA241

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableFirstContactSafetyTips is true."
        }
    }
}
