# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA142", "EXO", "Security", "All" {
    It "ORCA142: Phish action set to Quarantine message." {
        $result = Test-ORCA142

        if($null -ne $result) {
            $result | Should -Be $true -Because "Phish action set to Quarantine message."
        }
    }
}
