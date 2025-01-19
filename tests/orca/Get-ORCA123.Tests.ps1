# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA123", "EXO", "Security", "All" {
    It "ORCA123: Unusual Characters Safety Tips" {
        $result = Get-ORCA123

        if($null -ne $result) {
            $result | Should -Be $true -Because "Unusual Characters Safety Tips is enabled"
        }
    }
}
