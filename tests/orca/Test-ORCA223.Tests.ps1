# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.223", "EXO", "Security" {
    It "ORCA.223: User impersonation action is set to move to Quarantine." {
        $result = Test-ORCA223

        if($null -ne $result) {
            $result | Should -Be $true -Because "User impersonation action is set to move to Quarantine."
        }
    }
}
