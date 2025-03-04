# Generated on 03/04/2025 10:12:41 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA233_1", "EXO", "Security", "All" {
    It "ORCA233_1: Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors." {
        $result = Test-ORCA233_1

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors."
        }
    }
}
