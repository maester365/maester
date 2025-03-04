# Generated on 03/04/2025 09:42:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA106", "EXO", "Security", "All" {
    It "ORCA106: Quarantine retention period is 30 days." {
        $result = Test-ORCA106

        if($null -ne $result) {
            $result | Should -Be $true -Because "Quarantine retention period is 30 days."
        }
    }
}
