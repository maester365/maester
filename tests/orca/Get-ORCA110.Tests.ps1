# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA110", "EXO", "Security", "All" {
    It "ORCA110: Internal Sender Notifications" {
        $result = Get-ORCA110

        if($null -ne $result) {
            $result | Should -Be $true -Because "Internal Sender notifications are disabled"
        }
    }
}
