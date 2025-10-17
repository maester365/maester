# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.110", "EXO", "Security" {
    It "ORCA.110: Internal Sender notifications are disabled." {
        $result = Test-ORCA110

        if($null -ne $result) {
            $result | Should -Be $true -Because "Internal Sender notifications are disabled."
        }
    }
}
