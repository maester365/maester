# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.239", "EXO", "Security" {
    It "ORCA.239: No exclusions for the built-in protection policies." {
        $result = Test-ORCA239

        if($null -ne $result) {
            $result | Should -Be $true -Because "No exclusions for the built-in protection policies."
        }
    }
}
