# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.233.1", "EXO", "Security" {
    It "ORCA.233.1: Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors." {
        $result = Test-ORCA233_1

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are pointed directly at EOP or enhanced filtering is configured on all default connectors."
        }
    }
}
