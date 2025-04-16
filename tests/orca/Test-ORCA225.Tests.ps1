# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.225", "EXO", "Security", "All" {
    It "ORCA.225: Safe Documents is enabled for Office clients." {
        $result = Test-ORCA225

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Documents is enabled for Office clients."
        }
    }
}
