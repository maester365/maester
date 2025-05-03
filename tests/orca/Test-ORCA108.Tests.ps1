# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.108", "EXO", "Security", "All" {
    It "ORCA.108: DKIM signing is set up for all your custom domains." {
        $result = Test-ORCA108

        if($null -ne $result) {
            $result | Should -Be $true -Because "DKIM signing is set up for all your custom domains."
        }
    }
}
