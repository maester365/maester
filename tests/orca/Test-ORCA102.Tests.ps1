# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.102", "EXO", "Security" {
    It "ORCA.102: Advanced Spam filter options are turned off." {
        $result = Test-ORCA102

        if($null -ne $result) {
            $result | Should -Be $true -Because "Advanced Spam filter options are turned off."
        }
    }
}
