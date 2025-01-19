# Generated on 01/18/2025 20:19:55 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA110", "EXO", "Security", "All" {
    It "ORCA110: Internal Sender Notifications" {
        $result = Test-ORCA110

        if($null -ne $result) {
            $result | Should -Be $true -Because "Internal Sender notifications are disabled"
        }
    }
}
