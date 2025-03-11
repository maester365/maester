# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA121", "EXO", "Security", "All" {
    It "ORCA121: Supported filter policy action used." {
        $result = Test-ORCA121

        if($null -ne $result) {
            $result | Should -Be $true -Because "Supported filter policy action used."
        }
    }
}
