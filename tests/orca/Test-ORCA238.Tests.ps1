# Generated on 03/04/2025 09:34:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA238", "EXO", "Security", "All" {
    It "ORCA238: Safe Links is enabled for office documents." {
        $result = Test-ORCA238

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for office documents."
        }
    }
}
