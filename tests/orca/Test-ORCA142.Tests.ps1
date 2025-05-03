# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.142", "EXO", "Security", "All" {
    It "ORCA.142: Phish action set to Quarantine message." {
        $result = Test-ORCA142

        if($null -ne $result) {
            $result | Should -Be $true -Because "Phish action set to Quarantine message."
        }
    }
}
