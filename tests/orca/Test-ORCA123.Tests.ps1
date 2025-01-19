# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA123", "EXO", "Security", "All" {
    It "ORCA123: Unusual Characters Safety Tips" {
        $result = Test-ORCA123

        if($null -ne $result) {
            $result | Should -Be $true -Because "Unusual Characters Safety Tips is enabled"
        }
    }
}
