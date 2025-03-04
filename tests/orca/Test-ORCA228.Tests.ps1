# Generated on 03/04/2025 09:34:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA228", "EXO", "Security", "All" {
    It "ORCA228: No trusted senders in Anti-phishing policy." {
        $result = Test-ORCA228

        if($null -ne $result) {
            $result | Should -Be $true -Because "No trusted senders in Anti-phishing policy."
        }
    }
}
