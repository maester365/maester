# Generated on 03/11/2025 11:45:07 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA243", "EXO", "Security", "All" {
    It "ORCA243: Authenticated Receive Chain is set up for domains not pointing to EOP/MDO, or all domains point to EOP/MDO." {
        $result = Test-ORCA243

        if($null -ne $result) {
            $result | Should -Be $true -Because "Authenticated Receive Chain is set up for domains not pointing to EOP/MDO, or all domains point to EOP/MDO."
        }
    }
}
