# Generated on 03/04/2025 09:34:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA179", "EXO", "Security", "All" {
    It "ORCA179: Safe Links is enabled intra-organization." {
        $result = Test-ORCA179

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled intra-organization."
        }
    }
}
