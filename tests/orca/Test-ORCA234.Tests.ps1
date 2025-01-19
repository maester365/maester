# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA234", "EXO", "Security", "All" {
    It "ORCA234: Do not let users click through Safe Documents for Office clients" {
        $result = Test-ORCA234

        if($null -ne $result) {
            $result | Should -Be $true -Because "Click through is disabled for Safe Documents"
        }
    }
}
