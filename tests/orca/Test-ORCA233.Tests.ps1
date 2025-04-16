# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.233", "EXO", "Security", "All" {
    It "ORCA.233: Domains are pointed directly at EOP or enhanced filtering is used." {
        $result = Test-ORCA233

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are pointed directly at EOP or enhanced filtering is used."
        }
    }
}
