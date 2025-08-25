# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.111", "EXO", "Security" {
    It "ORCA.111: Anti-phishing policy exists and EnableUnauthenticatedSender is true." {
        $result = Test-ORCA111

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableUnauthenticatedSender is true."
        }
    }
}
