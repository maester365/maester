# Generated on 01/18/2025 20:19:55 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA106", "EXO", "Security", "All" {
    It "ORCA106: Quarantine retention period" {
        $result = Test-ORCA106

        if($null -ne $result) {
            $result | Should -Be $true -Because "Quarantine retention period is 30 days"
        }
    }
}
