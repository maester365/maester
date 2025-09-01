# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.235", "EXO", "Security" {
    It "ORCA.235: SPF records is set up for all your custom domains." {
        $result = Test-ORCA235

        if($null -ne $result) {
            $result | Should -Be $true -Because "SPF records is set up for all your custom domains."
        }
    }
}
