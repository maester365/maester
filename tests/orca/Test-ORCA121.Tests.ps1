# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.121", "EXO", "Security" {
    It "ORCA.121: Supported filter policy action used." {
        $result = Test-ORCA121

        if($null -ne $result) {
            $result | Should -Be $true -Because "Supported filter policy action used."
        }
    }
}
