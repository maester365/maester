# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.222", "EXO", "Security" {
    It "ORCA.222: Domain Impersonation action is set to move to Quarantine." {
        $result = Test-ORCA222

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domain Impersonation action is set to move to Quarantine."
        }
    }
}
