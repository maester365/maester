# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.238", "EXO", "Security", "All" {
    It "ORCA.238: Safe Links is enabled for office documents." {
        $result = Test-ORCA238

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for office documents."
        }
    }
}
