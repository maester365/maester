# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.241", "EXO", "Security" {
    It "ORCA.241: Anti-phishing policy exists and EnableFirstContactSafetyTips is true." {
        $result = Test-ORCA241

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableFirstContactSafetyTips is true."
        }
    }
}
