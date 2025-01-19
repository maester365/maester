# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA225", "EXO", "Security", "All" {
    It "ORCA225: Safe Documents for Office clients" {
        $result = Test-ORCA225

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Documents is enabled for Office clients"
        }
    }
}
