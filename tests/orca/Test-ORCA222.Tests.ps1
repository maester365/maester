# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA222", "EXO", "Security", "All" {
    It "ORCA222: Domain Impersonation action is set to move to Quarantine." {
        $result = Test-ORCA222

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domain Impersonation action is set to move to Quarantine."
        }
    }
}
