# Generated on 03/04/2025 09:34:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA233", "EXO", "Security", "All" {
    It "ORCA233: Domains are pointed directly at EOP or enhanced filtering is used." {
        $result = Test-ORCA233

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are pointed directly at EOP or enhanced filtering is used."
        }
    }
}
