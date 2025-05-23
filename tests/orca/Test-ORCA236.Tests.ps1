# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.236", "EXO", "Security", "All" {
    It "ORCA.236: Safe Links is enabled for emails." {
        $result = Test-ORCA236

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for emails."
        }
    }
}
