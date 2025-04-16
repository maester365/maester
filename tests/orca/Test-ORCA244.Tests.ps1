# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.244", "EXO", "Security", "All" {
    It "ORCA.244: Policies are configured to honor sending domains DMARC." {
        $result = Test-ORCA244

        if($null -ne $result) {
            $result | Should -Be $true -Because "Policies are configured to honor sending domains DMARC."
        }
    }
}
