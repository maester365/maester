# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.111", "EXO", "Security", "All" {
    It "ORCA.111: Anti-phishing policy exists and EnableUnauthenticatedSender is true." {
        $result = Test-ORCA111

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableUnauthenticatedSender is true."
        }
    }
}
