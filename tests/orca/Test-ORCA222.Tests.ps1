# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA222", "EXO", "Security", "All" {
    It "ORCA222: Domain Impersonation Action" {
        $result = Test-ORCA222

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domain Impersonation action is set to move to Quarantine"
        }
    }
}
