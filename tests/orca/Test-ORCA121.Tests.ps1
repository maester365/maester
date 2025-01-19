# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA121", "EXO", "Security", "All" {
    It "ORCA121: Supported filter policy action" {
        $result = Test-ORCA121

        if($null -ne $result) {
            $result | Should -Be $true -Because "Supported filter policy action used"
        }
    }
}
