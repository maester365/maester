# Generated on 01/18/2025 19:34:48 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA243", "EXO", "Security", "All" {
    It "ORCA243: Authenticated Receive Chain (ARC)" {
        $result = Test-ORCA243

        if($null -ne $result) {
            $result | Should -Be $true -Because "Authenticated Receive Chain is set up for domains not pointing to EOP/MDO, or all domains point to EOP/MDO."
        }
    }
}
