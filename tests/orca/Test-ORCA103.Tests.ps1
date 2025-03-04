# Generated on 03/04/2025 10:12:40 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA103", "EXO", "Security", "All" {
    It "ORCA103: Outbound spam filter policy settings configured." {
        $result = Test-ORCA103

        if($null -ne $result) {
            $result | Should -Be $true -Because "Outbound spam filter policy settings configured."
        }
    }
}
