# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.179", "EXO", "Security", "All" {
    It "ORCA.179: Safe Links is enabled intra-organization." {
        $result = Test-ORCA179

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled intra-organization."
        }
    }
}
