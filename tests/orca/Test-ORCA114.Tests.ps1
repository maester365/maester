# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA114", "EXO", "Security", "All" {
    It "ORCA114: IP Allow Lists" {
        $result = Test-ORCA114

        if($null -ne $result) {
            $result | Should -Be $true -Because "No IP Allow Lists have been configured"
        }
    }
}
