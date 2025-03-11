# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA120_phish", "EXO", "Security", "All" {
    It "ORCA120_phish: Zero Hour Autopurge Enabled for Phish." {
        $result = Test-ORCA120_phish

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge Enabled for Phish."
        }
    }
}
