# Generated on 03/04/2025 09:42:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA110", "EXO", "Security", "All" {
    It "ORCA110: Internal Sender notifications are disabled." {
        $result = Test-ORCA110

        if($null -ne $result) {
            $result | Should -Be $true -Because "Internal Sender notifications are disabled."
        }
    }
}
