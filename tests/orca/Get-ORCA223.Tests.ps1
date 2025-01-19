# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA223", "EXO", "Security", "All" {
    It "ORCA223: User Impersonation Action" {
        $result = Get-ORCA223

        if($null -ne $result) {
            $result | Should -Be $true -Because "User impersonation action is set to move to Quarantine"
        }
    }
}
