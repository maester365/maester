# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA120", "EXO", "Security", "All" {
    It "ORCA120: Zero Hour Autopurge Enabled for Spam" {
        $result = Test-ORCA120

        if($null -ne $result) {
            $result | Should -Be $true -Because "Zero Hour Autopurge is Enabled"
        }
    }
}
