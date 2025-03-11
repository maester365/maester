# Generated on 03/11/2025 11:45:07 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA244", "EXO", "Security", "All" {
    It "ORCA244: Policies are configured to honor sending domains DMARC." {
        $result = Test-ORCA244

        if($null -ne $result) {
            $result | Should -Be $true -Because "Policies are configured to honor sending domains DMARC."
        }
    }
}
