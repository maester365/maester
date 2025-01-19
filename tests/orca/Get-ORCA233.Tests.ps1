# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA233", "EXO", "Security", "All" {
    It "ORCA233: Domains" {
        $result = Get-ORCA233

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are pointed directly at EOP or enhanced filtering is used"
        }
    }
}
