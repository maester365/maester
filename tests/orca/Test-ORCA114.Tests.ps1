# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.114", "EXO", "Security", "All" {
    It "ORCA.114: No IP Allow Lists have been configured." {
        $result = Test-ORCA114

        if($null -ne $result) {
            $result | Should -Be $true -Because "No IP Allow Lists have been configured."
        }
    }
}
