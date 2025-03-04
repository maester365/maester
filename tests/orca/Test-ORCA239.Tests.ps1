# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA239", "EXO", "Security", "All" {
    It "ORCA239: No exclusions for the built-in protection policies." {
        $result = Test-ORCA239

        if($null -ne $result) {
            $result | Should -Be $true -Because "No exclusions for the built-in protection policies."
        }
    }
}
