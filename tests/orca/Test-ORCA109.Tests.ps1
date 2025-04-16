# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.109", "EXO", "Security", "All" {
    It "ORCA.109: Senders are not being allow listed in an unsafe manner." {
        $result = Test-ORCA109

        if($null -ne $result) {
            $result | Should -Be $true -Because "Senders are not being allow listed in an unsafe manner."
        }
    }
}
