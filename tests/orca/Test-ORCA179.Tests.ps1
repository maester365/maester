# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA179", "EXO", "Security", "All" {
    It "ORCA179: Intra-organization Safe Links" {
        $result = Test-ORCA179

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled intra-organization"
        }
    }
}
