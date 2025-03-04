# Generated on 03/04/2025 09:34:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA114", "EXO", "Security", "All" {
    It "ORCA114: No IP Allow Lists have been configured." {
        $result = Test-ORCA114

        if($null -ne $result) {
            $result | Should -Be $true -Because "No IP Allow Lists have been configured."
        }
    }
}
