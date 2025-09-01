# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.108", "EXO", "Security" {
    It "ORCA.108: DKIM signing is set up for all your custom domains." {
        $result = Test-ORCA108

        if($null -ne $result) {
            $result | Should -Be $true -Because "DKIM signing is set up for all your custom domains."
        }
    }
}
