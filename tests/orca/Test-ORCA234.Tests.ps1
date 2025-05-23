# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.234", "EXO", "Security", "All" {
    It "ORCA.234: Click through is disabled for Safe Documents." {
        $result = Test-ORCA234

        if($null -ne $result) {
            $result | Should -Be $true -Because "Click through is disabled for Safe Documents."
        }
    }
}
