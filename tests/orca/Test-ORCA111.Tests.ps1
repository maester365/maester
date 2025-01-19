# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA111", "EXO", "Security", "All" {
    It "ORCA111: Unauthenticated Sender (tagging)" {
        $result = Test-ORCA111

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-phishing policy exists and EnableUnauthenticatedSender is true"
        }
    }
}
