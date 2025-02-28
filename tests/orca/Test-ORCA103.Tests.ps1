# Generated on 01/19/2025 07:06:35 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA103", "EXO", "Security", "All" {
    It "ORCA103: Outbound spam filter policy settings" {
        $result = Test-ORCA103

        if($null -ne $result) {
            $result | Should -Be $true -Because "Outbound spam filter policy settings configured"
        }
    }
}
