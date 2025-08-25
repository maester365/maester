# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.106", "EXO", "Security" {
    It "ORCA.106: Quarantine retention period is 30 days." {
        $result = Test-ORCA106

        if($null -ne $result) {
            $result | Should -Be $true -Because "Quarantine retention period is 30 days."
        }
    }
}
