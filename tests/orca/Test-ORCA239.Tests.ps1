# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.239", "EXO", "Security", "All" {
    It "ORCA.239: No exclusions for the built-in protection policies." {
        $result = Test-ORCA239

        if($null -ne $result) {
            $result | Should -Be $true -Because "No exclusions for the built-in protection policies."
        }
    }
}
