# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA238", "EXO", "Security", "All" {
    It "ORCA238: Safe Links protections for links in office documents" {
        $result = Test-ORCA238

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for office documents"
        }
    }
}
