# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.110", "EXO", "Security", "All" {
    It "ORCA.110: Internal Sender notifications are disabled." {
        $result = Test-ORCA110

        if($null -ne $result) {
            $result | Should -Be $true -Because "Internal Sender notifications are disabled."
        }
    }
}
