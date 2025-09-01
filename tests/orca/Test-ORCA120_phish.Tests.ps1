# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.120.1", "EXO", "Security" {
    It "ORCA.120.1: Zero Hour Autopurge Enabled for Phish." {
        $result = Test-ORCA120_phish

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge Enabled for Phish."
        }
    }
}
