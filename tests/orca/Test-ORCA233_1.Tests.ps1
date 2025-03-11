# Generated on 03/11/2025 11:45:07 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA233_1", "EXO", "Security", "All" {
    It "ORCA233_1: Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors." {
        $result = Test-ORCA233_1

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors."
        }
    }
}
