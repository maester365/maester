# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.102", "EXO", "Security", "All" {
    It "ORCA.102: Advanced Spam filter options are turned off." {
        $result = Test-ORCA102

        if($null -ne $result) {
            $result | Should -Be $true -Because "Advanced Spam filter options are turned off."
        }
    }
}
