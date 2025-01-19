# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA228", "EXO", "Security", "All" {
    It "ORCA228: Anti-phishing trusted senders" {
        $result = Test-ORCA228

        if($null -ne $result) {
            $result | Should -Be $true -Because "No trusted senders in Anti-phishing policy"
        }
    }
}
