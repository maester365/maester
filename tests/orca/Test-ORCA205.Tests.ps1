# Generated on 01/19/2025 05:57:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA205", "EXO", "Security", "All" {
    It "ORCA205: Common Attachment Type Filter" {
        $result = Test-ORCA205

        if($null -ne $result) {
            $result | Should -Be $true -Because "Common attachment type filter is enabled"
        }
    }
}
