# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA106", "EXO", "Security", "All" {
    It "ORCA106: Quarantine retention period" {
        $result = Get-ORCA106

        if($null -ne $result) {
            $result | Should -Be $true -Because "Quarantine retention period is 30 days"
        }
    }
}
