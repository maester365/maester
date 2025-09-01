# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.103", "EXO", "Security" {
    It "ORCA.103: Outbound spam filter policy settings configured." {
        $result = Test-ORCA103

        if($null -ne $result) {
            $result | Should -Be $true -Because "Outbound spam filter policy settings configured."
        }
    }
}
