# Generated on 01/19/2025 05:57:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA142", "EXO", "Security", "All" {
    It "ORCA142: Phish Action" {
        $result = Test-ORCA142

        if($null -ne $result) {
            $result | Should -Be $true -Because "Phish action set to Quarantine message"
        }
    }
}
