# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA205", "EXO", "Security", "All" {
    It "ORCA205: Common Attachment Type Filter" {
        $result = Test-ORCA205

        if($null -ne $result) {
            $result | Should -Be $true -Because "Common attachment type filter is enabled"
        }
    }
}
