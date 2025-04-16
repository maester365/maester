# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.235", "EXO", "Security", "All" {
    It "ORCA.235: SPF records is set up for all your custom domains." {
        $result = Test-ORCA235

        if($null -ne $result) {
            $result | Should -Be $true -Because "SPF records is set up for all your custom domains."
        }
    }
}
