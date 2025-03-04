# Generated on 03/04/2025 10:12:41 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA120_spam", "EXO", "Security", "All" {
    It "ORCA120_spam: Zero Hour Autopurge Enabled for Spam." {
        $result = Test-ORCA120_spam

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge Enabled for Spam."
        }
    }
}
