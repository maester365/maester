# Generated on 03/04/2025 10:12:41 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA120_phish", "EXO", "Security", "All" {
    It "ORCA120_phish: Zero Hour Autopurge Enabled for Phish." {
        $result = Test-ORCA120_phish

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge Enabled for Phish."
        }
    }
}
