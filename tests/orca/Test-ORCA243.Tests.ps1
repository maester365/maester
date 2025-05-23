# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.243", "EXO", "Security", "All" {
    It "ORCA.243: Authenticated Receive Chain is set up for domains not pointing to EOP/MDO, or all domains point to EOP/MDO." {
        $result = Test-ORCA243

        if($null -ne $result) {
            $result | Should -Be $true -Because "Authenticated Receive Chain is set up for domains not pointing to EOP/MDO, or all domains point to EOP/MDO."
        }
    }
}
