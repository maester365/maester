# Generated on 03/04/2025 09:34:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA109", "EXO", "Security", "All" {
    It "ORCA109: Senders are not being allow listed in an unsafe manner." {
        $result = Test-ORCA109

        if($null -ne $result) {
            $result | Should -Be $true -Because "Senders are not being allow listed in an unsafe manner."
        }
    }
}
