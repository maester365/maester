# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA120_spam", "EXO", "Security", "All" {
    It "ORCA120_spam: Zero Hour Autopurge Enabled for Spam." {
        $result = Test-ORCA120_spam

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge Enabled for Spam."
        }
    }
}
