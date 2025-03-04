# Generated on 03/04/2025 10:12:41 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA234", "EXO", "Security", "All" {
    It "ORCA234: Click through is disabled for Safe Documents." {
        $result = Test-ORCA234

        if($null -ne $result) {
            $result | Should -Be $true -Because "Click through is disabled for Safe Documents."
        }
    }
}
