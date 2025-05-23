# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.120.3", "EXO", "Security", "All" {
    It "ORCA.120.3: Zero Hour Autopurge Enabled for Spam." {
        $result = Test-ORCA120_spam

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge Enabled for Spam."
        }
    }
}
