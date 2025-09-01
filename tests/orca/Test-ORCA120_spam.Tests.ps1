# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.120.3", "EXO", "Security" {
    It "ORCA.120.3: Zero Hour Autopurge Enabled for Spam." {
        $result = Test-ORCA120_spam

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge Enabled for Spam."
        }
    }
}
