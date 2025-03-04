# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA236", "EXO", "Security", "All" {
    It "ORCA236: Safe Links is enabled for emails." {
        $result = Test-ORCA236

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for emails."
        }
    }
}
