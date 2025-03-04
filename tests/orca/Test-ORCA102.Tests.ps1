# Generated on 03/04/2025 09:42:22 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA102", "EXO", "Security", "All" {
    It "ORCA102: Advanced Spam filter options are turned off." {
        $result = Test-ORCA102

        if($null -ne $result) {
            $result | Should -Be $true -Because "Advanced Spam filter options are turned off."
        }
    }
}
