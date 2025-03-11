# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA123", "EXO", "Security", "All" {
    It "ORCA123: Unusual Characters Safety Tips is enabled." {
        $result = Test-ORCA123

        if($null -ne $result) {
            $result | Should -Be $true -Because "Unusual Characters Safety Tips is enabled."
        }
    }
}
