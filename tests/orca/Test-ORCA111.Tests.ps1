# Generated on 03/04/2025 10:12:40 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA111", "EXO", "Security", "All" {
    It "ORCA111: Anti-phishing policy exists and EnableUnauthenticatedSender is true." {
        $result = Test-ORCA111

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableUnauthenticatedSender is true."
        }
    }
}
