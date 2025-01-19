# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA103", "EXO", "Security", "All" {
    It "ORCA103: Outbound spam filter policy settings" {
        $result = Get-ORCA103

        if($null -ne $result) {
            $result | Should -Be $true -Because "Outbound spam filter policy settings configured"
        }
    }
}
